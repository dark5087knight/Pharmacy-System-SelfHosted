import 'package:flutter/material.dart';

class Location {
  final String rack;
  final String shelf;
  final String warehouse;

  Location({required this.rack, required this.shelf, required this.warehouse});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      rack: json['rack'] ?? '',
      shelf: json['shelf'] ?? '',
      warehouse: json['warehouse'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'rack': rack,
    'shelf': shelf,
    'warehouse': warehouse,
  };
}

class Medicine {
  final String id;
  final String name;
  final String genericName;
  final String brand;
  final String category;
  final String barcode;
  final String sku;
  final String batchNumber;
  final String manufactureDate;
  final String expiryDate;
  final int quantity;
  final String unit; // tablet, capsule, bottle, vial, tube, box, sachet
  final double purchasePrice;
  final double sellingPrice;
  final double discount;
  final double taxRate;
  final int lowStockThreshold;
  final Location location;
  final String status; // active, inactive, discontinued
  final bool controlled;
  final bool prescriptionRequired;
  final String supplierId;
  final String description;
  final List<String> sideEffects;
  final List<String> interactions;
  final String dosage;
  final String storage;
  final bool isPinned;

  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.brand,
    required this.category,
    required this.barcode,
    required this.sku,
    required this.batchNumber,
    required this.manufactureDate,
    required this.expiryDate,
    required this.quantity,
    required this.unit,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.discount,
    required this.taxRate,
    required this.lowStockThreshold,
    required this.location,
    required this.status,
    required this.controlled,
    required this.prescriptionRequired,
    required this.supplierId,
    required this.description,
    required this.sideEffects,
    required this.interactions,
    required this.dosage,
    required this.storage,
    required this.isPinned,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      genericName: json['genericName'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      barcode: json['barcode'] ?? '',
      sku: json['sku'] ?? '',
      batchNumber: json['batchNumber'] ?? '',
      manufactureDate: json['manufactureDate'] ?? '',
      expiryDate: json['expiryDate'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit'] ?? '',
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 0,
      location: Location.fromJson(json['location'] ?? {}),
      status: json['status'] ?? 'active',
      controlled: json['controlled'] ?? false,
      prescriptionRequired: json['prescriptionRequired'] ?? false,
      supplierId: json['supplierId'] ?? '',
      description: json['description'] ?? '',
      sideEffects: List<String>.from(json['sideEffects'] ?? []),
      interactions: List<String>.from(json['interactions'] ?? []),
      dosage: json['dosage'] ?? '',
      storage: json['storage'] ?? '',
      isPinned: json['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'genericName': genericName,
    'brand': brand,
    'category': category,
    'barcode': barcode,
    'sku': sku,
    'batchNumber': batchNumber,
    'manufactureDate': manufactureDate,
    'expiryDate': expiryDate,
    'quantity': quantity,
    'unit': unit,
    'purchasePrice': purchasePrice,
    'sellingPrice': sellingPrice,
    'discount': discount,
    'taxRate': taxRate,
    'lowStockThreshold': lowStockThreshold,
    'location': location.toJson(),
    'status': status,
    'controlled': controlled,
    'prescriptionRequired': prescriptionRequired,
    'supplierId': supplierId,
    'description': description,
    'sideEffects': sideEffects,
    'interactions': interactions,
    'dosage': dosage,
    'storage': storage,
    'isPinned': isPinned,
  };

  Medicine copyWith({
    String? id,
    String? name,
    String? genericName,
    String? brand,
    String? category,
    String? barcode,
    String? sku,
    String? batchNumber,
    String? manufactureDate,
    String? expiryDate,
    int? quantity,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? discount,
    double? taxRate,
    int? lowStockThreshold,
    Location? location,
    String? status,
    bool? controlled,
    bool? prescriptionRequired,
    String? supplierId,
    String? description,
    List<String>? sideEffects,
    List<String>? interactions,
    String? dosage,
    String? storage,
    bool? isPinned,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      sku: sku ?? this.sku,
      batchNumber: batchNumber ?? this.batchNumber,
      manufactureDate: manufactureDate ?? this.manufactureDate,
      expiryDate: expiryDate ?? this.expiryDate,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      location: location ?? this.location,
      status: status ?? this.status,
      controlled: controlled ?? this.controlled,
      prescriptionRequired: prescriptionRequired ?? this.prescriptionRequired,
      supplierId: supplierId ?? this.supplierId,
      description: description ?? this.description,
      sideEffects: sideEffects ?? this.sideEffects,
      interactions: interactions ?? this.interactions,
      dosage: dosage ?? this.dosage,
      storage: storage ?? this.storage,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class Supplier {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String address;
  final double rating;
  final double outstandingBalance;
  final double totalPurchased;
  final String status; // active, inactive
  final String? notes;

  Supplier({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.address,
    required this.rating,
    required this.outstandingBalance,
    required this.totalPurchased,
    required this.status,
    this.notes,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      company: json['company'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (json['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
      totalPurchased: (json['totalPurchased'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'active',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'company': company,
    'email': email,
    'phone': phone,
    'address': address,
    'rating': rating,
    'outstandingBalance': outstandingBalance,
    'totalPurchased': totalPurchased,
    'status': status,
    'notes': notes,
  };

  Supplier copyWith({
    String? id,
    String? name,
    String? company,
    String? email,
    String? phone,
    String? address,
    double? rating,
    double? outstandingBalance,
    double? totalPurchased,
    String? status,
    String? notes,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      totalPurchased: totalPurchased ?? this.totalPurchased,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class Insurance {
  final String provider;
  final String policy;

  Insurance({required this.provider, required this.policy});

  factory Insurance.fromJson(Map<String, dynamic> json) {
    return Insurance(
      provider: json['provider'] ?? '',
      policy: json['policy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'policy': policy,
  };
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? dateOfBirth;
  final int loyaltyPoints;
  final String membershipLevel; // bronze, silver, gold, platinum
  final List<String> allergies;
  final Insurance? insurance;
  final double balance;
  final double totalSpent;
  final int visits;
  final String notes;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.dateOfBirth,
    required this.loyaltyPoints,
    required this.membershipLevel,
    required this.allergies,
    this.insurance,
    required this.balance,
    required this.totalSpent,
    required this.visits,
    required this.notes,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      dateOfBirth: json['dateOfBirth'],
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt() ?? 0,
      membershipLevel: json['membershipLevel'] ?? 'bronze',
      allergies: List<String>.from(json['allergies'] ?? []),
      insurance: json['insurance'] != null ? Insurance.fromJson(json['insurance']) : null,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'dateOfBirth': dateOfBirth,
    'loyaltyPoints': loyaltyPoints,
    'membershipLevel': membershipLevel,
    'allergies': allergies,
    'insurance': insurance?.toJson(),
    'balance': balance,
    'totalSpent': totalSpent,
    'visits': visits,
    'notes': notes,
  };

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? dateOfBirth,
    int? loyaltyPoints,
    String? membershipLevel,
    List<String>? allergies,
    Insurance? insurance,
    double? balance,
    double? totalSpent,
    int? visits,
    String? notes,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      membershipLevel: membershipLevel ?? this.membershipLevel,
      allergies: allergies ?? this.allergies,
      insurance: insurance ?? this.insurance,
      balance: balance ?? this.balance,
      totalSpent: totalSpent ?? this.totalSpent,
      visits: visits ?? this.visits,
      notes: notes ?? this.notes,
    );
  }
}


class PrescriptionItem {
  final String medicineId;
  final int quantity;
  final String dosage;

  PrescriptionItem({required this.medicineId, required this.quantity, required this.dosage});

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      medicineId: json['medicineId'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      dosage: json['dosage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'medicineId': medicineId,
    'quantity': quantity,
    'dosage': dosage,
  };
}

class Prescription {
  final String id;
  final String customerId;
  final String doctorName;
  final String doctorLicense;
  final String issuedAt;
  final String status; // pending, validated, fulfilled, expired, rejected
  final String? imageUrl;
  final String? notes;
  final int refillsRemaining;
  final List<PrescriptionItem> items;

  Prescription({
    required this.id,
    required this.customerId,
    required this.doctorName,
    required this.doctorLicense,
    required this.issuedAt,
    required this.status,
    this.imageUrl,
    this.notes,
    required this.refillsRemaining,
    required this.items,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    return Prescription(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      doctorName: json['doctorName'] ?? '',
      doctorLicense: json['doctorLicense'] ?? '',
      issuedAt: json['issuedAt'] ?? '',
      status: json['status'] ?? 'pending',
      imageUrl: json['imageUrl'],
      notes: json['notes'],
      refillsRemaining: (json['refillsRemaining'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List?)?.map((i) => PrescriptionItem.fromJson(i)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'doctorName': doctorName,
    'doctorLicense': doctorLicense,
    'issuedAt': issuedAt,
    'status': status,
    'imageUrl': imageUrl,
    'notes': notes,
    'refillsRemaining': refillsRemaining,
    'items': items.map((i) => i.toJson()).toList(),
  };

  Prescription copyWith({
    String? id,
    String? customerId,
    String? doctorName,
    String? doctorLicense,
    String? issuedAt,
    String? status,
    String? imageUrl,
    String? notes,
    int? refillsRemaining,
    List<PrescriptionItem>? items,
  }) {
    return Prescription(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      doctorName: doctorName ?? this.doctorName,
      doctorLicense: doctorLicense ?? this.doctorLicense,
      issuedAt: issuedAt ?? this.issuedAt,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      items: items ?? this.items,
    );
  }
}

class CartItem {
  final String medicineId;
  final String name;
  int quantity;
  final double unitPrice;
  final int maxQuantity;
  final double discount;
  final double taxRate;
  
  TextEditingController? controller;
  FocusNode? focusNode;

  CartItem({
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.maxQuantity,
    required this.discount,
    required this.taxRate,
    this.controller,
    this.focusNode,
  });
}

class SaleItem {
  final String medicineId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double taxRate;

  SaleItem({
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.taxRate,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      medicineId: json['medicineId'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'medicineId': medicineId,
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discount': discount,
    'taxRate': taxRate,
  };
}

class Sale {
  final String id;
  final String invoiceNumber;
  final String? customerId;
  final String cashierId;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod; // cash, card, insurance, mixed
  final String status; // completed, held, refunded, void
  final String createdAt;

  Sale({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.cashierId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      customerId: json['customerId'],
      cashierId: json['cashierId'] ?? '',
      items: (json['items'] as List?)?.map((i) => SaleItem.fromJson(i)).toList() ?? [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] ?? 'cash',
      status: json['status'] ?? 'completed',
      createdAt: json['createdAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'customerId': customerId,
    'cashierId': cashierId,
    'items': items.map((i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'discount': discount,
    'tax': tax,
    'total': total,
    'paymentMethod': paymentMethod,
    'status': status,
    'createdAt': createdAt,
  };
}

class PurchaseOrderItem {
  final String medicineId;
  final int quantity;
  final double unitCost;

  PurchaseOrderItem({required this.medicineId, required this.quantity, required this.unitCost});

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      medicineId: json['medicineId'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'medicineId': medicineId,
    'quantity': quantity,
    'unitCost': unitCost,
  };
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String supplierId;
  final String status; // draft, pending, approved, received, cancelled
  final List<PurchaseOrderItem> items;
  final double total;
  final String createdAt;
  final String? expectedAt;
  final String? receivedAt;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.status,
    required this.items,
    required this.total,
    required this.createdAt,
    this.expectedAt,
    this.receivedAt,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] ?? '',
      poNumber: json['poNumber'] ?? '',
      supplierId: json['supplierId'] ?? '',
      status: json['status'] ?? 'draft',
      items: (json['items'] as List?)?.map((i) => PurchaseOrderItem.fromJson(i)).toList() ?? [],
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] ?? '',
      expectedAt: json['expectedAt'],
      receivedAt: json['receivedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'poNumber': poNumber,
    'supplierId': supplierId,
    'status': status,
    'items': items.map((i) => i.toJson()).toList(),
    'total': total,
    'createdAt': createdAt,
    'expectedAt': expectedAt,
    'receivedAt': receivedAt,
  };
}

class StaffMember {
  final String id;
  final String name;
  final String username;
  final String email;
  final String role; // admin, manager, pharmacist, cashier
  final String status; // active, off-shift, suspended
  final String shift; // morning, evening, night
  final String joinedAt;
  final String lastSeen;

  StaffMember({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    required this.status,
    required this.shift,
    required this.joinedAt,
    required this.lastSeen,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'cashier',
      status: json['status'] ?? 'active',
      shift: json['shift'] ?? 'morning',
      joinedAt: json['joinedAt'] ?? json['joined_at'] ?? '',
      lastSeen: json['lastSeen'] ?? json['last_seen'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'role': role,
    'status': status,
    'shift': shift,
    'joinedAt': joinedAt,
    'lastSeen': lastSeen,
  };

  StaffMember copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? role,
    String? status,
    String? shift,
    String? joinedAt,
    String? lastSeen,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      status: status ?? this.status,
      shift: shift ?? this.shift,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class ActivityEvent {
  final String id;
  final String type; // sale, inventory, prescription, purchase, user, system
  final String message;
  final String actor;
  final String at;
  final String? severity; // info, warning, critical

  ActivityEvent({
    required this.id,
    required this.type,
    required this.message,
    required this.actor,
    required this.at,
    this.severity,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] ?? '',
      type: json['type'] ?? 'info',
      message: json['message'] ?? '',
      actor: json['actor'] ?? '',
      at: json['at'] ?? '',
      severity: json['severity'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'message': message,
    'actor': actor,
    'at': at,
    'severity': severity,
  };
}

class Notification {
  final String id;
  final String title;
  final String body;
  final String category; // expiry, stock, payment, supplier, system
  final String priority; // low, normal, high, critical
  final bool read;
  final String at;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.read,
    required this.at,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      category: json['category'] ?? 'system',
      priority: json['priority'] ?? 'normal',
      read: json['read'] ?? false,
      at: json['at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'category': category,
    'priority': priority,
    'read': read,
    'at': at,
  };

  Notification copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? priority,
    bool? read,
    String? at,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      read: read ?? this.read,
      at: at ?? this.at,
    );
  }
}
