import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/coupon_model.dart';

class CouponRepository {
  final SupabaseClient _client;

  CouponRepository(this._client);

  Future<List<CouponModel>> getAllCoupons() async {
    final response = await _client
        .from('coupons')
        .select()
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => CouponModel.fromJson(json))
        .toList();
  }

  Future<List<CouponModel>> getActiveCoupons() async {
    final response = await _client
        .from('coupons')
        .select()
        .eq('status', 'active')
        .gte('valid_until', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => CouponModel.fromJson(json))
        .toList();
  }

  Future<CouponModel?> getCouponByCode(String code) async {
    final response = await _client
        .from('coupons')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
    
    if (response == null) return null;
    return CouponModel.fromJson(response);
  }

  Future<void> createCoupon(CouponModel coupon) async {
    await _client.from('coupons').insert(coupon.toJson());
  }

  Future<void> updateCoupon(CouponModel coupon) async {
    await _client.from('coupons').update({
      'code': coupon.code,
      'description': coupon.description,
      'type': coupon.type.name,
      'value': coupon.value,
      'min_purchase_amount': coupon.minPurchaseAmount,
      'max_discount_amount': coupon.maxDiscountAmount,
      'usage_limit': coupon.usageLimit,
      'valid_from': coupon.validFrom.toIso8601String(),
      'valid_until': coupon.validUntil.toIso8601String(),
      'status': coupon.status.name,
      'notes': coupon.notes,
      'applicable_plans': coupon.applicablePlans,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', coupon.id);
  }

  Future<void> deleteCoupon(String id) async {
    await _client.from('coupons').delete().eq('id', id);
  }

  Future<void> toggleCouponStatus(String id, String status) async {
    await _client.from('coupons').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<Map<String, dynamic>> validateCoupon(String code, double purchaseAmount) async {
    try {
      final result = await _client.rpc('validate_coupon', params: {
        'p_code': code.toUpperCase(),
        'p_purchase_amount': purchaseAmount,
      });
      
      if (result is List && result.isNotEmpty) {
        return result.first as Map<String, dynamic>;
      }
      return {'is_valid': false, 'message': 'Invalid response'};
    } catch (e) {
      // Fallback to manual validation
      final coupon = await getCouponByCode(code);
      if (coupon == null) {
        return {'is_valid': false, 'message': 'Coupon not found'};
      }
      if (!coupon.isValid) {
        return {'is_valid': false, 'message': 'Coupon is expired or inactive'};
      }
      if (coupon.minPurchaseAmount != null && purchaseAmount < coupon.minPurchaseAmount!) {
        return {'is_valid': false, 'message': 'Minimum purchase of ₹${coupon.minPurchaseAmount} required'};
      }
      
      final discount = coupon.calculateDiscount(purchaseAmount);
      return {
        'is_valid': true,
        'discount_amount': discount,
        'coupon_id': coupon.id,
        'message': 'Coupon applied successfully'
      };
    }
  }
}
