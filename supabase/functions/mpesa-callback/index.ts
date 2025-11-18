// M-Pesa STK Push Callback Handler
// Deploy: supabase functions deploy mpesa-callback
// Webhook URL: https://[your-project].supabase.co/functions/v1/mpesa-callback

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface MpesaCallbackItem {
  Name: string
  Value: string | number
}

interface MpesaCallbackBody {
  Name: string
  Value: any
}

interface MpesaCallback {
  Body: {
    stkCallback: {
      MerchantRequestID: string
      CheckoutRequestID: string
      ResultCode: number
      ResultDesc: string
      CallbackMetadata?: {
        Item: MpesaCallbackItem[]
      }
    }
  }
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('📱 M-Pesa callback received')
    
    const callbackData: MpesaCallback = await req.json()
    console.log('Callback data:', JSON.stringify(callbackData, null, 2))

    const { stkCallback } = callbackData.Body

    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Extract callback metadata if payment was successful
    let transactionData: any = {
      merchant_request_id: stkCallback.MerchantRequestID,
      checkout_request_id: stkCallback.CheckoutRequestID,
      result_code: stkCallback.ResultCode,
      result_desc: stkCallback.ResultDesc,
      status: stkCallback.ResultCode === 0 ? 'completed' : 'failed',
      transaction_timestamp: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    // If payment successful, extract transaction details
    if (stkCallback.ResultCode === 0 && stkCallback.CallbackMetadata) {
      const metadata = stkCallback.CallbackMetadata.Item
      
      const getMetadataValue = (name: string) => {
        const item = metadata.find((i: MpesaCallbackItem) => i.Name === name)
        return item ? item.Value : null
      }

      transactionData = {
        ...transactionData,
        amount: getMetadataValue('Amount'),
        transaction_id: getMetadataValue('MpesaReceiptNumber'),
        phone_number: getMetadataValue('PhoneNumber')?.toString(),
        transaction_timestamp: new Date(getMetadataValue('TransactionDate')?.toString() || Date.now()).toISOString(),
        balance: getMetadataValue('Balance') || null,
      }

      console.log('✅ Payment successful:', transactionData.transaction_id)
    } else {
      console.log('❌ Payment failed:', stkCallback.ResultDesc)
    }

    // Update or insert transaction record
    const { data: existingTransaction } = await supabaseClient
      .from('mpesa_transactions')
      .select('*')
      .eq('checkout_request_id', stkCallback.CheckoutRequestID)
      .single()

    if (existingTransaction) {
      // Update existing transaction
      const { error: updateError } = await supabaseClient
        .from('mpesa_transactions')
        .update(transactionData)
        .eq('checkout_request_id', stkCallback.CheckoutRequestID)

      if (updateError) {
        console.error('Failed to update transaction:', updateError)
        throw updateError
      }

      console.log('Updated transaction:', existingTransaction.id)

      // If payment successful and order exists, update order status
      if (stkCallback.ResultCode === 0 && existingTransaction.order_id) {
        await updateOrderStatus(supabaseClient, existingTransaction.order_id, 'paid')
        
        // Generate and send receipt
        await generateReceipt(
          supabaseClient,
          transactionData.transaction_id,
          existingTransaction.order_id,
          existingTransaction.user_auth_id
        )
      }
    } else {
      console.log('⚠️ No pending transaction found for checkout request:', stkCallback.CheckoutRequestID)
      
      // Create transaction record if it doesn't exist (shouldn't happen normally)
      if (stkCallback.ResultCode === 0 && transactionData.transaction_id) {
        const { error: insertError } = await supabaseClient
          .from('mpesa_transactions')
          .insert({
            ...transactionData,
            transaction_type: 'payment',
            business_short_code: Deno.env.get('MPESA_SHORTCODE') || 'UNKNOWN',
          })

        if (insertError) {
          console.error('Failed to insert transaction:', insertError)
        }
      }
    }

    // Return success response to Safaricom
    return new Response(
      JSON.stringify({
        ResultCode: 0,
        ResultDesc: 'Accepted'
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Callback processing error:', error)
    
    // Still return success to Safaricom to avoid retries
    return new Response(
      JSON.stringify({
        ResultCode: 0,
        ResultDesc: 'Accepted'
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  }
})

async function updateOrderStatus(supabaseClient: any, orderId: string, status: string) {
  try {
    const { error } = await supabaseClient
      .from('orders')
      .update({ 
        status,
        updated_at: new Date().toISOString()
      })
      .eq('id', orderId)

    if (error) {
      console.error('Failed to update order status:', error)
    } else {
      console.log(`✅ Order ${orderId} marked as ${status}`)
    }
  } catch (error) {
    console.error('Error updating order status:', error)
  }
}

async function generateReceipt(
  supabaseClient: any,
  transactionId: string,
  orderId: string,
  userAuthId: string
) {
  try {
    // Fetch order details
    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .select(`
        *,
        users!inner(email, full_name, phone),
        order_items(
          quantity,
          unit_price,
          total_price,
          item_name,
          item_type
        )
      `)
      .eq('id', orderId)
      .single()

    if (orderError || !order) {
      console.error('Failed to fetch order for receipt:', orderError)
      return
    }

    // Generate receipt number
    const { data: receiptNum } = await supabaseClient
      .rpc('generate_receipt_number')

    const receiptNumber = receiptNum || `RCP-${Date.now()}`

    // Get business details from locations table
    const { data: location } = await supabaseClient
      .from('locations')
      .select('*')
      .eq('is_active', true)
      .single()

    // Insert receipt
    const { data: receipt, error: receiptError } = await supabaseClient
      .from('receipts')
      .insert({
        receipt_number: receiptNumber,
        transaction_id: transactionId,
        receipt_type: 'payment',
        issue_date: new Date().toISOString(),
        customer_name: order.users.full_name,
        customer_phone: order.users.phone,
        customer_email: order.users.email,
        subtotal: Math.round(order.subtotal),
        tax_amount: Math.round(order.tax || 0),
        discount_amount: 0,
        total_amount: Math.round(order.total),
        business_name: location?.business_name || "Ouma's Delicacy",
        business_address: location?.address || '',
        business_phone: location?.phone || '',
        business_email: location?.email || '',
        payment_method: 'M-Pesa',
        currency: 'KES',
      })
      .select()
      .single()

    if (receiptError) {
      console.error('Failed to create receipt:', receiptError)
      return
    }

    console.log('✅ Receipt created:', receipt.receipt_number)

    // Insert receipt items
    const receiptItems = order.order_items.map((item: any) => ({
      receipt_id: receipt.id,
      item_description: item.item_name,
      quantity: item.quantity,
      unit_price: Math.round(item.unit_price),
      total_price: Math.round(item.total_price),
      item_code: item.item_type,
    }))

    const { error: itemsError } = await supabaseClient
      .from('receipt_items')
      .insert(receiptItems)

    if (itemsError) {
      console.error('Failed to create receipt items:', itemsError)
    } else {
      console.log(`✅ Receipt items created: ${receiptItems.length} items`)
    }

    // Send receipt email (optional)
    await sendReceiptEmail(order, receipt, receiptItems)

  } catch (error) {
    console.error('Error generating receipt:', error)
  }
}

async function sendReceiptEmail(order: any, receipt: any, items: any[]) {
  try {
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    if (!resendApiKey) {
      console.log('⚠️ RESEND_API_KEY not configured, skipping email')
      return
    }

    const html = generateReceiptHTML(order, receipt, items)

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: "Ouma's Delicacy <receipts@oumasdelicacy.com>",
        to: order.users.email,
        subject: `Payment Receipt ${receipt.receipt_number} - Ouma's Delicacy`,
        html
      })
    })

    if (emailResponse.ok) {
      console.log('✅ Receipt email sent to:', order.users.email)
    } else {
      const errorText = await emailResponse.text()
      console.error('Failed to send receipt email:', errorText)
    }
  } catch (error) {
    console.error('Error sending receipt email:', error)
  }
}

function generateReceiptHTML(order: any, receipt: any, items: any[]): string {
  const itemsHTML = items.map(item => `
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb;">
        ${item.item_description}
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: center;">
        ${item.quantity}
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: right;">
        KSh ${item.unit_price.toLocaleString()}
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: right;">
        <strong>KSh ${item.total_price.toLocaleString()}</strong>
      </td>
    </tr>
  `).join('')

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Payment Receipt</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
    <h1 style="margin: 0; font-size: 28px;">Ouma's Delicacy</h1>
    <p style="margin: 10px 0 0 0; opacity: 0.9;">Payment Receipt</p>
  </div>

  <div style="background: #f9fafb; padding: 20px; border-left: 1px solid #e5e7eb; border-right: 1px solid #e5e7eb;">
    <div style="display: flex; justify-content: space-between; margin-bottom: 10px;">
      <div>
        <strong>Receipt Number:</strong><br>
        ${receipt.receipt_number}
      </div>
      <div style="text-align: right;">
        <strong>Order ID:</strong><br>
        ${order.short_id}
      </div>
    </div>
    <div style="display: flex; justify-content: space-between;">
      <div>
        <strong>Date:</strong><br>
        ${new Date(receipt.issue_date).toLocaleString()}
      </div>
      <div style="text-align: right;">
        <strong>Payment Method:</strong><br>
        M-Pesa
      </div>
    </div>
  </div>

  <div style="background: white; padding: 20px; border: 1px solid #e5e7eb;">
    <h3 style="margin-top: 0; color: #667eea;">Customer Details</h3>
    <p style="margin: 5px 0;"><strong>Name:</strong> ${receipt.customer_name}</p>
    <p style="margin: 5px 0;"><strong>Phone:</strong> ${receipt.customer_phone}</p>
    <p style="margin: 5px 0;"><strong>Email:</strong> ${receipt.customer_email}</p>
  </div>

  <div style="background: white; padding: 20px; border: 1px solid #e5e7eb; border-top: none; margin-top: 20px;">
    <h3 style="margin-top: 0; color: #667eea;">Order Items</h3>
    <table style="width: 100%; border-collapse: collapse;">
      <thead>
        <tr style="background: #f9fafb;">
          <th style="padding: 12px; text-align: left; border-bottom: 2px solid #e5e7eb;">Item</th>
          <th style="padding: 12px; text-align: center; border-bottom: 2px solid #e5e7eb;">Qty</th>
          <th style="padding: 12px; text-align: right; border-bottom: 2px solid #e5e7eb;">Price</th>
          <th style="padding: 12px; text-align: right; border-bottom: 2px solid #e5e7eb;">Total</th>
        </tr>
      </thead>
      <tbody>
        ${itemsHTML}
      </tbody>
    </table>
  </div>

  <div style="background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none;">
    <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
      <span>Subtotal:</span>
      <span>KSh ${receipt.subtotal.toLocaleString()}</span>
    </div>
    <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
      <span>Delivery Fee:</span>
      <span>KSh ${Math.round(order.delivery_fee || 0).toLocaleString()}</span>
    </div>
    ${receipt.tax_amount > 0 ? `
    <div style="display: flex; justify-content: space-between; margin-bottom: 8px;">
      <span>Tax:</span>
      <span>KSh ${receipt.tax_amount.toLocaleString()}</span>
    </div>
    ` : ''}
    <div style="display: flex; justify-content: space-between; padding-top: 12px; border-top: 2px solid #e5e7eb; font-size: 18px; font-weight: bold; color: #667eea;">
      <span>Total Paid:</span>
      <span>KSh ${receipt.total_amount.toLocaleString()}</span>
    </div>
  </div>

  <div style="background: white; padding: 20px; text-align: center; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 10px 10px;">
    <p style="margin: 0; color: #6b7280; font-size: 14px;">
      Thank you for your order!<br>
      For questions, contact us at ${receipt.business_phone || 'support@oumasdelicacy.com'}
    </p>
  </div>
</body>
</html>
  `
}
