// lib/models/receipt.dart

class Receipt {
  final String id;
  final String receiptNumber;
  final String transactionId;
  final String receiptType;
  final DateTime issueDate;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String currency;
  final String paymentMethod;
  final String businessName;
  final String? businessAddress;
  final String? businessPhone;
  final String? businessEmail;
  final String? taxIdentification;
  final String? notes;
  final bool isPrinted;
  final DateTime? printedAt;
  final DateTime createdAt;
  final List<ReceiptItem> items;

  Receipt({
    required this.id,
    required this.receiptNumber,
    required this.transactionId,
    required this.receiptType,
    required this.issueDate,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
    required this.paymentMethod,
    required this.businessName,
    this.businessAddress,
    this.businessPhone,
    this.businessEmail,
    this.taxIdentification,
    this.notes,
    required this.isPrinted,
    this.printedAt,
    required this.createdAt,
    this.items = const [],
  });

  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      id: json['id'] as String,
      receiptNumber: json['receipt_number'] as String,
      transactionId: json['transaction_id'] as String,
      receiptType: json['receipt_type'] as String,
      issueDate: DateTime.parse(json['issue_date'] as String),
      customerName: json['customer_name'] as String? ?? 'N/A',
      customerPhone: json['customer_phone'] as String? ?? 'N/A',
      customerEmail: json['customer_email'] as String?,
      subtotal: _parseAmount(json['subtotal']),
      taxAmount: _parseAmount(json['tax_amount']),
      discountAmount: _parseAmount(json['discount_amount']),
      totalAmount: _parseAmount(json['total_amount']),
      currency: json['currency'] as String? ?? 'KES',
      paymentMethod: json['payment_method'] as String? ?? 'M-Pesa',
      businessName: json['business_name'] as String? ?? "Ouma's Delicacy",
      businessAddress: json['business_address'] as String?,
      businessPhone: json['business_phone'] as String?,
      businessEmail: json['business_email'] as String?,
      taxIdentification: json['tax_identification'] as String?,
      notes: json['notes'] as String?,
      isPrinted: json['is_printed'] as bool? ?? false,
      printedAt: json['printed_at'] != null 
          ? DateTime.parse(json['printed_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: json['receipt_items'] != null
          ? (json['receipt_items'] as List)
              .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_number': receiptNumber,
      'transaction_id': transactionId,
      'receipt_type': receiptType,
      'issue_date': issueDate.toIso8601String(),
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'payment_method': paymentMethod,
      'business_name': businessName,
      'business_address': businessAddress,
      'business_phone': businessPhone,
      'business_email': businessEmail,
      'tax_identification': taxIdentification,
      'notes': notes,
      'is_printed': isPrinted,
      'printed_at': printedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ReceiptItem {
  final String id;
  final String receiptId;
  final String itemDescription;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double taxRate;
  final double taxAmount;
  final double discountRate;
  final double discountAmount;
  final String? itemCode;
  final DateTime createdAt;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    required this.itemDescription,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.taxRate,
    required this.taxAmount,
    required this.discountRate,
    required this.discountAmount,
    this.itemCode,
    required this.createdAt,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      id: json['id'] as String,
      receiptId: json['receipt_id'] as String,
      itemDescription: json['item_description'] as String,
      quantity: json['quantity'] as int,
      unitPrice: Receipt._parseAmount(json['unit_price']),
      totalPrice: Receipt._parseAmount(json['total_price']),
      taxRate: Receipt._parseAmount(json['tax_rate']),
      taxAmount: Receipt._parseAmount(json['tax_amount']),
      discountRate: Receipt._parseAmount(json['discount_rate']),
      discountAmount: Receipt._parseAmount(json['discount_amount']),
      itemCode: json['item_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'item_description': itemDescription,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'discount_rate': discountRate,
      'discount_amount': discountAmount,
      'item_code': itemCode,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
