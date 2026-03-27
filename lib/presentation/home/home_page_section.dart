import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/home_header.dart';
import 'widgets/hero_section.dart';

import 'widgets/stats_section.dart';
import 'widgets/service_list_section.dart';
import 'widgets/products_section.dart';
import 'widgets/about_section.dart';
import 'widgets/contact_section.dart';

class HomePageSection extends ConsumerWidget {
  const HomePageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── Fixed Glass Header ───
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.lightBlue,
              automaticallyImplyLeading: false,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              toolbarHeight: 72,
              flexibleSpace: const HomeHeader(),
            ),

            // ─── Hero Section ───
            const SliverToBoxAdapter(
              child: Stack(clipBehavior: Clip.none, children: [HeroSection()]),
            ),

            // ─── Spacer ───
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ─── Stats Section ───
            const SliverToBoxAdapter(child: StatsSection()),

            // ─── Services Section ───
            const SliverToBoxAdapter(child: ServiceListSection()),

            // ─── Products Section ───
            const SliverToBoxAdapter(child: ProductsSection()),

            // ─── About Section ───
            const SliverToBoxAdapter(child: AboutSection()),

            // ─── Contact Section ───
            const SliverToBoxAdapter(child: ContactSection()),

            // ─── Bottom Padding for Nav Bar ───
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
