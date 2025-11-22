// M-Pesa STK Push Initiator
// Deploy: supabase functions deploy mpesa-stk-push
// Call from Flutter app to initiate M-Pesa payment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface STKPushRequest {
  phoneNumber: string
  amount: number
  orderId?: string
  accountReference: string
  transactionDesc: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get request body
    const { phoneNumber, amount, orderId, accountReference, transactionDesc }: STKPushRequest = await req.json()

    // Validate inputs
    if (!phoneNumber || !amount || !accountReference) {
      throw new Error('Missing required fields: phoneNumber, amount, accountReference')
    }

    // Format phone number (remove leading 0, add 254)
    const formattedPhone = formatPhoneNumber(phoneNumber)
    
    console.log('📱 Initiating STK Push:', {
      phone: formattedPhone,
      amount,
      orderId,
      accountReference
    })

    // Get M-Pesa access token
    const accessToken = await getMpesaAccessToken()

    // Get environment variables
    const shortCode = Deno.env.get('MPESA_SHORTCODE')
    const passkey = Deno.env.get('MPESA_PASSKEY')
    const callbackUrl = Deno.env.get('MPESA_CALLBACK_URL') || 
      `${Deno.env.get('SUPABASE_URL')}/functions/v1/mpesa-callback`

    if (!shortCode || !passkey) {
      throw new Error('M-Pesa configuration missing: MPESA_SHORTCODE or MPESA_PASSKEY')
    }

    // Generate password and timestamp
    const timestamp = generateTimestamp()
    const password = btoa(`${shortCode}${passkey}${timestamp}`)

    // Prepare STK Push request
    const stkPushPayload = {
      BusinessShortCode: shortCode,
      Password: password,
      Timestamp: timestamp,
      TransactionType: 'CustomerPayBillOnline',
      Amount: Math.round(amount),
      PartyA: formattedPhone,
      PartyB: shortCode,
      PhoneNumber: formattedPhone,
      CallBackURL: callbackUrl,
      AccountReference: accountReference,
      TransactionDesc: transactionDesc || 'Payment for order'
    }

    console.log('Sending STK Push request...')

    // Determine environment (production by default)
    const environment = Deno.env.get('MPESA_ENVIRONMENT') || 'production'
    const baseUrl = environment === 'sandbox' 
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke'

    console.log(`📡 Using M-Pesa ${environment} environment: ${baseUrl}`)

    // Send STK Push request to Safaricom
    const mpesaResponse = await fetch(
      `${baseUrl}/mpesa/stkpush/v1/processrequest`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(stkPushPayload)
      }
    )

    const mpesaData = await mpesaResponse.json()
    console.log('M-Pesa response:', mpesaData)

    if (mpesaData.ResponseCode !== '0') {
      throw new Error(`STK Push failed: ${mpesaData.ResponseDescription || mpesaData.errorMessage}`)
    }

    // Get user auth ID from JWT token
    const authHeader = req.headers.get('authorization')
    let userAuthId = null
    
    if (authHeader) {
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      )
      
      const token = authHeader.replace('Bearer ', '')
      const { data: { user } } = await supabaseClient.auth.getUser(token)
      userAuthId = user?.id
    }

    // Store pending transaction in database
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Generate unique transaction ID (will be updated with M-Pesa receipt number on callback)
    const transactionId = `TXN-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`

    const { data: transaction, error: dbError } = await supabaseClient
      .from('mpesa_transactions')
      .insert({
        transaction_id: transactionId,
        merchant_request_id: mpesaData.MerchantRequestID,
        checkout_request_id: mpesaData.CheckoutRequestID,
        transaction_type: 'payment',
        status: 'pending',
        amount: Math.round(amount),
        phone_number: formattedPhone,
        account_reference: accountReference,
        transaction_desc: transactionDesc,
        business_short_code: shortCode,
        user_auth_id: userAuthId,
        order_id: orderId || null,
        transaction_timestamp: new Date().toISOString(),
      })
      .select()
      .single()

    if (dbError) {
      console.error('Failed to store transaction:', dbError)
      // Don't throw error - STK push was successful
    } else {
      console.log('✅ Transaction stored:', transaction.id)
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        message: mpesaData.CustomerMessage || 'STK Push sent successfully',
        merchantRequestId: mpesaData.MerchantRequestID,
        checkoutRequestId: mpesaData.CheckoutRequestID,
        transactionId: transaction?.id
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ STK Push error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})

async function getMpesaAccessToken(): Promise<string> {
  const consumerKey = Deno.env.get('MPESA_CONSUMER_KEY')
  const consumerSecret = Deno.env.get('MPESA_CONSUMER_SECRET')

  if (!consumerKey || !consumerSecret) {
    throw new Error('M-Pesa credentials not configured')
  }

  const auth = btoa(`${consumerKey}:${consumerSecret}`)

  // Use production URL (sandbox if MPESA_ENVIRONMENT=sandbox)
  const environment = Deno.env.get('MPESA_ENVIRONMENT') || 'production'
  const baseUrl = environment === 'sandbox' 
    ? 'https://sandbox.safaricom.co.ke'
    : 'https://api.safaricom.co.ke'

  const response = await fetch(
    `${baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
    {
      headers: {
        'Authorization': `Basic ${auth}`
      }
    }
  )

  if (!response.ok) {
    throw new Error('Failed to get M-Pesa access token')
  }

  const data = await response.json()
  return data.access_token
}

function generateTimestamp(): string {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const hours = String(now.getHours()).padStart(2, '0')
  const minutes = String(now.getMinutes()).padStart(2, '0')
  const seconds = String(now.getSeconds()).padStart(2, '0')
  
  return `${year}${month}${day}${hours}${minutes}${seconds}`
}

function formatPhoneNumber(phone: string): string {
  // Remove any spaces, dashes, or plus signs
  let cleaned = phone.replace(/[\s\-+]/g, '')
  
  // If starts with 0, replace with 254
  if (cleaned.startsWith('0')) {
    cleaned = '254' + cleaned.substring(1)
  }
  
  // If doesn't start with 254, add it
  if (!cleaned.startsWith('254')) {
    cleaned = '254' + cleaned
  }
  
  return cleaned
}
