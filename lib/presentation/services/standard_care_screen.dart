import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/providers/standard_service_providers.dart';
import '../../application/providers/auth_providers.dart';
import '../../domain/models/standard_service_model.dart';

class StandardCareScreen extends ConsumerWidget {
  const StandardCareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(activeStandardServicesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6F6),
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Washing Care',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: servicesAsync.when(
          loading: () => _buildSkeletonGrid(),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Oops! Something went wrong.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(activeStandardServicesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (services) {
            if (services.isEmpty) return _buildEmptyState();
            return _buildServicesGrid(ref, services);
          },
        ),
      ),
    );
  }

  Widget _buildServicesGrid(WidgetRef ref, List<StandardServiceModel> services) {
    // Group services by category
    final categories = <String, List<StandardServiceModel>>{};
    for (final service in services) {
      categories.putIfAbsent(service.category, () => []).add(service);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Services by category
        ...categories.entries.expand(
          (entry) => [
            // Category Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0541E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      entry.key.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Services in category - Single column layout
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final service = entry.value[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildWashingCareCard(context, ref, service),
                    );
                  },
                  childCount: entry.value.length,
                ),
              ),
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  /// Modern Washing Care Card - Matches screenshot design
  Widget _buildWashingCareCard(
      BuildContext context, WidgetRef ref, StandardServiceModel service) {
    // Map of service names to local asset images
    final serviceAssetImages = {
      'Exterior Shine': 'assets/images/standard care.jpg',
      'Quick Interior': 'assets/images/drycleaning.jpg',
      'Only Interior Cleaning': 'assets/images/drycleaning.jpg',
      'Deep Dry Cleaning': 'assets/images/drycleaning.jpg',
      'Full Service Wash': 'assets/images/standard care.jpg',
      'Premium Detail': 'assets/images/Rubbing polishing.jpg',
      'Engine Bay Cleaning': 'assets/images/Maintenance.jpg',
      'Leather Treatment': 'assets/images/Accessories.jpg',
    };

    // Map of categories to local asset images (for category-based fallback)
    final categoryAssetImages = {
      'Exterior Wash': 'assets/images/standard care.jpg',
      'Interior Wash': 'assets/images/drycleaning.jpg',
      'Detailing': 'assets/images/Rubbing polishing.jpg',
      'Maintenance': 'assets/images/Maintenance.jpg',
      'Accessories': 'assets/images/Accessories.jpg',
    };

    // Priority: 1. Admin-set imageUrl from database, 2. Service name match, 3. Category match, 4. Default
    String? imagePath;
    
    // First check if admin has set a custom image
    if (service.imageUrl != null && service.imageUrl!.isNotEmpty) {
      imagePath = service.imageUrl;
    } else {
      // Check service name match
      imagePath = serviceAssetImages[service.name];
      // Fall back to category match
      if (imagePath == null) {
        imagePath = categoryAssetImages[service.category];
      }
      // Final fallback
      imagePath ??= 'assets/images/standard care.jpg';
    }

    // Determine if we should use AssetImage or NetworkImage
    final bool useNetworkImage = imagePath!.startsWith('http');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Image
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              color: Colors.grey[100],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: useNetworkImage
                  ? Image.network(
                      imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (__, ___, ____) => Image.asset(
                        'assets/images/standard care.jpg',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (__, ___, ____) => _buildPlaceholderIcon(),
                    ),
            ),
          ),

          // Service Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Name
                Text(
                  service.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  service.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Price and Book Now Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${service.price.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final isGuest = ref.read(isGuestProvider);
                        if (isGuest) {
                          Navigator.pushNamed(context, '/login');
                        } else {
                          Navigator.pushNamed(
                            context,
                            '/payment',
                            arguments: {
                              'isService': true,
                              'serviceName': service.name,
                              'servicePrice': service.price,
                              'serviceId': service.id,
                              'serviceDescription': service.description,
                            },
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0541E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'BOOK NOW',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: Icon(
        Icons.local_car_wash_rounded,
        size: 40,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.car_repair_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Services Available',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon — we\'re adding new services!',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: 4,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildSkeletonCard(),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
