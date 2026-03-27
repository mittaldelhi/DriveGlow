import 'package:flutter/material.dart';
import 'package:shinex/theme/app_theme.dart';

class ProductsSection extends StatelessWidget {
  const ProductsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Column(
        children: [
          // ─── Header ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upgrade Your Ride',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: PremiumTheme.darkBg,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/store');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: PremiumTheme.orangePrimary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'Visit Store',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PremiumTheme.orangePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Horizontal Scroll List ───
          SizedBox(
            height: 220,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildProductCard(
                  title: 'LED Headlights',
                  category: 'Lighting',
                  image:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDeUwoQ45Fk6HKVACeDmVNIM_CrhsDWHbi6RyjOEnyBZWQaVaxfF95opTq6flshl-1Ts5AZzUK7xxEPVxLqRvPYPkS5r1lEfu3pBHZDjDI8CBV9CZ_McO5B7ydz_6KW6bjdeo5FfAI8sD4NCAVFHpe-JEymSNwRV0ZpwSG1a5U9JNu9oyFkWrt_QgvT3IsJgu5LSVprhqIrMWtaLODzpzLuQw4CfbhlT4Popr8PdhjFYqh9Nm6vJy2fe4bwhKfuGUZcFUI1gzunwk4',
                ),
                const SizedBox(width: 16),
                _buildProductCard(
                  title: 'Premium Perfume',
                  category: 'Fragrance',
                  image:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDWU6_R47xmujpTMNSrNeWkMN6wsZ5X1ZpaDuH2Bs6zO5I2wsrx-c_DywhBTWn_zr5DOYGl1cir3ASXsqHwFOJKnsx4RLiSovg0K3-SzhRuLQbJZNax4_t3ZzJinkdLyM74XRmZ5nF6nrrh8BIIyR9htw8-zkR5HaglVasfeDJj0bcdqU0tGwcg_F88EPQoGlHb6xE8w9oZqjl24IOwYa7JYlJcY479_Oy1zEE5BP4bgjilVjFlqStfeX4s-3Yk5y6nQltAIVoKmRI',
                ),
                const SizedBox(width: 16),
                _buildProductCard(
                  title: 'Nappa Seat Covers',
                  category: 'Interior',
                  image:
                      'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?q=80&w=1974&auto=format&fit=crop', // Premium Seat/Interior
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard({
    required String title,
    required String category,
    required String image,
  }) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.grey),
              ),
            ),
            // Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
            // Text
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
