// Edge Function to send order receipt emails
// Deploy: supabase functions deploy send-order-receipt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { orderId } = await req.json()

    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Fetch order details with related data
    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .select(`
        *,
        users!inner(email, name, phone),
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
      throw new Error(`Order not found: ${orderError?.message}`)
    }

    // Generate receipt HTML
    const receiptHTML = generateReceiptHTML(order)

    // Send email using Resend (you'll need to sign up at resend.com)
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    if (!resendApiKey) {
      throw new Error('RESEND_API_KEY not configured')
    }

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: 'Ouma\'s Delicacy <receipts@oumasdelicacy.com>',
        to: order.users.email,
        subject: `Order Receipt #${order.short_id} - Ouma's Delicacy`,
        html: receiptHTML
      })
    })

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text()
      throw new Error(`Failed to send email: ${errorText}`)
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Receipt sent successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

function generateReceiptHTML(order: any): string {
  const items = order.order_items.map((item: any) => `
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb;">
        ${item.item_name}
        <br><small style="color: #6b7280;">${item.item_type}</small>
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: center;">
        ${item.quantity}
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: right;">
        KES ${item.unit_price.toFixed(0)}
      </td>
      <td style="padding: 12px; border-bottom: 1px solid #e5e7eb; text-align: right; font-weight: 600;">
        KES ${item.total_price.toFixed(0)}
      </td>
    </tr>
  `).join('')

  const subtotal = order.total_amount - (order.delivery_fee || 0)

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Order Receipt</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f3f4f6;">
  <div style="max-width: 600px; margin: 20px auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%); color: white; padding: 30px 20px; text-align: center;">
      <h1 style="margin: 0; font-size: 28px;">Ouma's Delicacy</h1>
      <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Order Receipt</p>
    </div>

    <!-- Order Info -->
    <div style="padding: 30px 20px; border-bottom: 2px solid #e5e7eb;">
      <div style="display: flex; justify-content: space-between; margin-bottom: 20px;">
        <div>
          <h2 style="margin: 0 0 10px 0; font-size: 24px; color: #111827;">Order #${order.short_id}</h2>
          <p style="margin: 0; color: #6b7280;">
            ${new Date(order.created_at).toLocaleDateString('en-US', { 
              weekday: 'long', 
              year: 'numeric', 
              month: 'long', 
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit'
            })}
          </p>
        </div>
        <div style="text-align: right;">
          <span style="display: inline-block; padding: 6px 16px; background: ${
            order.status === 'pending' ? '#fef3c7' : 
            order.status === 'confirmed' ? '#dbeafe' : 
            order.status === 'delivered' ? '#d1fae5' : '#fee2e2'
          }; color: ${
            order.status === 'pending' ? '#92400e' : 
            order.status === 'confirmed' ? '#1e40af' : 
            order.status === 'delivered' ? '#065f46' : '#991b1b'
          }; border-radius: 20px; font-size: 14px; font-weight: 600; text-transform: capitalize;">
            ${order.status}
          </span>
        </div>
      </div>

      <!-- Customer Info -->
      <div style="background: #f9fafb; padding: 16px; border-radius: 8px; margin-top: 20px;">
        <h3 style="margin: 0 0 12px 0; font-size: 16px; color: #374151;">Customer Information</h3>
        <p style="margin: 0 0 6px 0;"><strong>Name:</strong> ${order.users.name}</p>
        <p style="margin: 0 0 6px 0;"><strong>Phone:</strong> ${order.users.phone}</p>
        <p style="margin: 0;"><strong>Email:</strong> ${order.users.email}</p>
        ${order.delivery_address ? `<p style="margin: 6px 0 0 0;"><strong>Delivery Address:</strong> ${order.delivery_address}</p>` : ''}
      </div>
    </div>

    <!-- Order Items -->
    <div style="padding: 30px 20px;">
      <h3 style="margin: 0 0 20px 0; font-size: 18px; color: #111827;">Order Items</h3>
      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="background: #f9fafb;">
            <th style="padding: 12px; text-align: left; font-weight: 600; color: #374151;">Item</th>
            <th style="padding: 12px; text-align: center; font-weight: 600; color: #374151;">Qty</th>
            <th style="padding: 12px; text-align: right; font-weight: 600; color: #374151;">Price</th>
            <th style="padding: 12px; text-align: right; font-weight: 600; color: #374151;">Total</th>
          </tr>
        </thead>
        <tbody>
          ${items}
        </tbody>
      </table>
    </div>

    <!-- Totals -->
    <div style="padding: 20px; background: #f9fafb; border-top: 2px solid #e5e7eb;">
      <div style="display: flex; justify-content: space-between; margin-bottom: 12px;">
        <span style="color: #6b7280;">Subtotal</span>
        <span style="font-weight: 600;">KES ${subtotal.toFixed(0)}</span>
      </div>
      ${order.delivery_fee ? `
      <div style="display: flex; justify-content: space-between; margin-bottom: 12px;">
        <span style="color: #6b7280;">Delivery Fee</span>
        <span style="font-weight: 600;">KES ${order.delivery_fee.toFixed(0)}</span>
      </div>
      ` : ''}
      <div style="display: flex; justify-content: space-between; padding-top: 12px; border-top: 2px solid #e5e7eb; margin-top: 12px;">
        <span style="font-size: 18px; font-weight: 700; color: #111827;">Total</span>
        <span style="font-size: 20px; font-weight: 700; color: #4f46e5;">KES ${order.total_amount.toFixed(0)}</span>
      </div>
      <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid #e5e7eb;">
        <div style="display: flex; justify-content: space-between;">
          <span style="color: #6b7280;">Payment Method</span>
          <span style="font-weight: 600; text-transform: capitalize;">${order.payment_method || 'M-Pesa'}</span>
        </div>
      </div>
    </div>

    <!-- Footer -->
    <div style="padding: 30px 20px; text-align: center; background: #f9fafb; border-top: 1px solid #e5e7eb;">
      <p style="margin: 0 0 10px 0; color: #6b7280; font-size: 14px;">Thank you for your order!</p>
      <p style="margin: 0; color: #9ca3af; font-size: 12px;">
        If you have any questions, please contact us at support@oumasdelicacy.com
      </p>
    </div>

  </div>
</body>
</html>
  `
}
