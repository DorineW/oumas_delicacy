// M-Pesa Transaction Status Query
// Deploy: supabase functions deploy mpesa-query-status
// This function queries M-Pesa for transaction status (works in sandbox!)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface QueryRequest {
  checkoutRequestId: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { checkoutRequestId }: QueryRequest = await req.json()

    if (!checkoutRequestId) {
      throw new Error('Missing checkoutRequestId')
    }

    console.log('🔍 Querying M-Pesa transaction status:', checkoutRequestId)

    // Get M-Pesa access token
    const accessToken = await getMpesaAccessToken()

    // Get environment variables
    const shortCode = Deno.env.get('MPESA_SHORTCODE')
    const passkey = Deno.env.get('MPESA_PASSKEY')

    if (!shortCode || !passkey) {
      throw new Error('M-Pesa configuration missing')
    }

    // Generate password and timestamp
    const timestamp = generateTimestamp()
    const password = btoa(`${shortCode}${passkey}${timestamp}`)

    // Prepare query request
    const queryPayload = {
      BusinessShortCode: shortCode,
      Password: password,
      Timestamp: timestamp,
      CheckoutRequestID: checkoutRequestId
    }

    // Determine environment
    const environment = Deno.env.get('MPESA_ENVIRONMENT') || 'production'
    const baseUrl = environment === 'sandbox' 
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke'

    console.log(`📡 Querying ${environment} M-Pesa API...`)

    // Query M-Pesa for transaction status
    const mpesaResponse = await fetch(
      `${baseUrl}/mpesa/stkpushquery/v1/query`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(queryPayload)
      }
    )

    const mpesaData = await mpesaResponse.json()
    console.log('📊 M-Pesa query response:', JSON.stringify(mpesaData, null, 2))
    console.log('🔢 ResultCode type:', typeof mpesaData.ResultCode, 'Value:', mpesaData.ResultCode)

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Check if transaction exists
    const { data: existingTransaction } = await supabaseClient
      .from('mpesa_transactions')
      .select('*')
      .eq('checkout_request_id', checkoutRequestId)
      .single()

    if (!existingTransaction) {
      console.warn('⚠️ Transaction not found in database')
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Transaction not found in database',
          mpesaResponse: mpesaData
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404
        }
      )
    }

    // ResultCode meanings:
    // 0 = Success
    // 1032 = Cancelled by user
    // 1037 = Timeout (user didn't enter PIN)
    // 1 = Insufficient funds
    // Other = Error

    // Convert to string for consistent comparison (M-Pesa can return number or string)
    // Handle undefined ResultCode (still pending)
    const resultCode = mpesaData.ResultCode !== undefined ? String(mpesaData.ResultCode) : null
    let status = 'pending'
    let errorMessage = null

    console.log('📊 Raw M-Pesa response:', JSON.stringify(mpesaData, null, 2))

    if (resultCode === null) {
      // Still pending - M-Pesa hasn't processed yet
      status = 'pending'
      console.log('⏳ Transaction still pending')
    } else if (resultCode === '0') {
      status = 'completed'
      console.log('✅ Payment successful!')
    } else if (resultCode === '1032') {
      status = 'cancelled'
      errorMessage = 'Transaction cancelled by user'
      console.log('❌ User cancelled transaction')
    } else if (resultCode === '1037') {
      status = 'failed'
      errorMessage = 'Transaction timeout - user did not enter PIN'
      console.log('⏱️ Transaction timed out')
    } else if (resultCode === '1') {
      status = 'failed'
      errorMessage = 'Insufficient funds'
      console.log('💰 Insufficient funds')
    } else {
      status = 'failed'
      errorMessage = mpesaData.ResultDesc || 'Transaction failed'
      console.log('❌ Transaction failed:', errorMessage)
    }

    // Update transaction in database (only if status changed)
    const updateData: any = {
      status,
      updated_at: new Date().toISOString()
    }
    
    // Only update result_code if it's not null
    if (resultCode !== null) {
      updateData.result_code = parseInt(resultCode, 10)
      updateData.result_desc = errorMessage || mpesaData.ResultDesc
    }
    
    const { data: updatedTransaction, error: updateError } = await supabaseClient
      .from('mpesa_transactions')
      .update(updateData)
      .eq('checkout_request_id', checkoutRequestId)
      .select()
      .single()

    if (updateError) {
      console.error('Failed to update transaction:', updateError)
      throw updateError
    }

    console.log('✅ Transaction updated:', updatedTransaction.id)

    // If payment successful, update order status
    if (status === 'completed' && existingTransaction.order_id) {
      console.log('📦 Updating order status to paid...')
      console.log('   Transaction ID:', existingTransaction.transaction_id)
      console.log('   Order ID:', existingTransaction.order_id)
      
      const { error: orderError } = await supabaseClient
        .from('orders')
        .update({ 
          status: 'paid',
          payment_method: 'mpesa',
          updated_at: new Date().toISOString()
        })
        .eq('id', existingTransaction.order_id)

      if (orderError) {
        console.error('❌ Failed to update order:', orderError)
      } else {
        console.log('✅ Order marked as paid')
      }

      // Generate receipt using proper function
      console.log('🧾 Starting receipt generation...')
      console.log('   Transaction ID:', existingTransaction.transaction_id)
      console.log('   Order ID:', existingTransaction.order_id)
      console.log('   User Auth ID:', existingTransaction.user_auth_id)
      
      try {
        await generateReceipt(
          supabaseClient,
          existingTransaction.transaction_id || `TXN-${Date.now()}`,
          existingTransaction.order_id,
          existingTransaction.user_auth_id
        )
        console.log('✅ Receipt generation completed successfully')
      } catch (receiptError) {
        console.error('❌ Failed to generate receipt:', receiptError)
        console.error('   Error details:', JSON.stringify(receiptError, null, 2))
        // Don't throw - payment was still successful
      }
    } else {
      // Log why receipt generation was skipped
      if (status !== 'completed') {
        console.log('⚠️ Receipt generation skipped: status is', status, 'not completed')
      } else if (!existingTransaction.order_id) {
        console.log('⚠️ Receipt generation skipped: no order_id found')
        console.log('   Transaction:', JSON.stringify(existingTransaction, null, 2))
      }
    }

    // Return response
    return new Response(
      JSON.stringify({
        success: true,
        status,
        resultCode,
        resultDesc: mpesaData.ResultDesc,
        transaction: updatedTransaction,
        mpesaResponse: mpesaData
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Query error:', error)
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

async function generateReceipt(
  supabaseClient: any,
  transactionId: string,
  orderId: string,
  userAuthId: string
) {
  try {
    console.log('🧾 generateReceipt() called with:', { transactionId, orderId, userAuthId })
    
    // Fetch order details with items
    console.log('📥 Fetching order and items...')
    const { data: orderItems, error: itemsError } = await supabaseClient
      .from('order_items')
      .select('quantity, unit_price, name')
      .eq('order_id', orderId)

    if (itemsError || !orderItems) {
      console.error('❌ Failed to fetch order items:', itemsError)
      return
    }

    console.log('✅ Order items fetched:', orderItems.length)

    // Calculate total from items
    const subtotal = orderItems.reduce((sum: number, item: any) => 
      sum + (item.quantity * item.unit_price), 0
    )

    console.log('💰 Calculated subtotal:', subtotal)

    // Fetch user details
    const { data: user } = await supabaseClient
      .from('users')
      .select('email, name, phone')
      .eq('auth_id', userAuthId)
      .single()

    // Fetch transaction for amount
    const { data: transaction } = await supabaseClient
      .from('mpesa_transactions')
      .select('amount, phone_number')
      .eq('transaction_id', transactionId)
      .single()

    console.log('✅ User and transaction fetched')

    // Generate receipt number
    console.log('🔢 Generating receipt number...')
    const { data: receiptNum, error: receiptNumError } = await supabaseClient
      .rpc('generate_receipt_number')

    if (receiptNumError) {
      console.error('❌ Failed to generate receipt number:', receiptNumError)
      return
    }

    const receiptNumber = receiptNum || `RCP-${Date.now()}`
    console.log('✅ Receipt number generated:', receiptNumber)

    // Get business details from locations table
    const { data: location } = await supabaseClient
      .from('locations')
      .select('*')
      .eq('is_active', true)
      .limit(1)
      .single()

    console.log('📝 Inserting receipt...')
    // Insert receipt
    const { data: receipt, error: receiptError } = await supabaseClient
      .from('receipts')
      .insert({
        receipt_number: receiptNumber,
        transaction_id: transactionId,
        receipt_type: 'payment',
        issue_date: new Date().toISOString(),
        customer_name: user?.name || 'Customer',
        customer_phone: transaction?.phone_number || user?.phone || '',
        customer_email: user?.email || '',
        subtotal: transaction?.amount || subtotal,
        tax_amount: 0,
        discount_amount: 0,
        total_amount: transaction?.amount || subtotal,
        business_name: location?.name || "Ouma's Delicacy",
        business_address: location?.address || 'Nairobi, Kenya',
        business_phone: location?.phone || '+254700000000',
        business_email: location?.email || 'receipts@oumasdelicacy.com',
        payment_method: 'M-Pesa',
        currency: 'KES',
      })
      .select()
      .single()

    if (receiptError) {
      console.error('❌ Failed to create receipt:', receiptError)
      console.error('   Error details:', JSON.stringify(receiptError, null, 2))
      return
    }

    console.log('✅ Receipt created:', receipt.receipt_number)
    console.log('   Receipt ID:', receipt.id)

    // Insert receipt items
    console.log('📦 Inserting receipt items...')
    const receiptItems = orderItems.map((item: any) => ({
      receipt_id: receipt.id,
      item_description: item.name || 'Item',
      quantity: item.quantity || 1,
      unit_price: item.unit_price || 0,
      total_price: (item.quantity || 1) * (item.unit_price || 0),
    }))

    console.log('   Items to insert:', receiptItems.length)

    const { error: itemsError2 } = await supabaseClient
      .from('receipt_items')
      .insert(receiptItems)

    if (itemsError2) {
      console.error('❌ Failed to create receipt items:', itemsError2)
      console.error('   Items:', JSON.stringify(receiptItems, null, 2))
    } else {
      console.log(`✅ Receipt items created: ${receiptItems.length} items`)
    }

  } catch (error) {
    console.error('❌ Error generating receipt:', error)
    console.error('   Error details:', JSON.stringify(error, null, 2))
  }
}
