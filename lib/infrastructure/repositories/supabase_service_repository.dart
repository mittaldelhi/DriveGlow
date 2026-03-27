import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/models/service_model.dart';
import '../../domain/repositories/service_repository.dart';

class SupabaseServiceRepository implements ServiceRepository {
  final _client = supabase.Supabase.instance.client;

  @override
  Future<List<ServiceModel>> getServices() async {
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('is_available', true);

      if (response.isNotEmpty) {
        return response.map((json) => ServiceModel.fromJson(json)).toList();
      }
    } catch (e) {
      // Fallback to service_pricing if services table is missing
      try {
        final pricing = await _client
            .from('service_pricing')
            .select()
            .eq('plan_type', 'One-Time');

        return (pricing as List)
            .map(
              (p) => ServiceModel(
                id: p['id'].toString(),
                title: p['service_name'],
                description: '${p['tier']} Specialization',
                basePrice: (p['price'] as num).toDouble(),
                iconName: 'local_car_wash',
                category: p['category'],
              ),
            )
            .toList();
      } catch (e2) {
        return _getDefaultServices();
      }
    }
    return _getDefaultServices();
  }

  List<ServiceModel> _getDefaultServices() {
    return [
      ServiceModel(
        id: '1',
        title: 'Exterior Detailing',
        description:
            'Professional hand wash, clay bar treatment, and wax protection.',
        basePrice: 499,
        iconName: 'local_car_wash',
        category: 'Standard',
      ),
      ServiceModel(
        id: '2',
        title: 'Interior Deep Clean',
        description:
            'Complete interior vacuum, steam cleaning, and sanitization.',
        basePrice: 799,
        iconName: 'cleaning_services',
        category: 'Standard',
      ),
      ServiceModel(
        id: '3',
        title: 'Ceramic Coating',
        description:
            '9H nano-ceramic protection with ultra-hydrophobic properties.',
        basePrice: 2999,
        iconName: 'shield',
        category: 'Premium',
      ),
    ];
  }

  @override
  Future<ServiceModel?> getServiceById(String id) async {
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('id', id)
          .single();

      return ServiceModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
