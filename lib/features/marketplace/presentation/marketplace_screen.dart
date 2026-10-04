import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/models.dart';
import '../application/marketplace_providers.dart';
import '../domain/models.dart';

/// Marketplace de AgeCare: cuidadoras, productos/ayudas técnicas y, para la
/// cuidadora, ofertas de trabajo.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isCaregiver = user?.primaryRole == RoleType.caregiver;

    final tabs = <Tab>[
      const Tab(text: 'Cuidadoras'),
      const Tab(text: 'Productos'),
      if (isCaregiver) const Tab(text: 'Trabajos'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace'),
          bottom: TabBar(
            isScrollable: false,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          children: [
            const _CaregiversTab(),
            const _ProductsTab(),
            if (isCaregiver) const _JobsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cuidadoras
// ---------------------------------------------------------------------------
class _CaregiversTab extends ConsumerStatefulWidget {
  const _CaregiversTab();

  @override
  ConsumerState<_CaregiversTab> createState() => _CaregiversTabState();
}

class _CaregiversTabState extends ConsumerState<_CaregiversTab> {
  final _zoneCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  CaregiverFilters _filters = const CaregiverFilters();

  @override
  void dispose() {
    _zoneCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    setState(() {
      _filters = CaregiverFilters(
        zone: _zoneCtrl.text.trim().isEmpty ? null : _zoneCtrl.text.trim(),
        specialty: _specialtyCtrl.text.trim().isEmpty
            ? null
            : _specialtyCtrl.text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final caregivers = ref.watch(caregiversProvider(_filters));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zoneCtrl,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(
                    labelText: 'Zona',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _specialtyCtrl,
                  onSubmitted: (_) => _apply(),
                  decoration: const InputDecoration(
                    labelText: 'Especialidad',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _apply,
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: caregivers.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(caregiversProvider(_filters)),
            ),
            data: (list) => list.isEmpty
                ? const EmptyView(
                    icon: Icons.person_search_rounded,
                    title: 'Sin resultados',
                    subtitle:
                        'No encontramos cuidadoras con esos filtros. Prueba con otros.',
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(caregiversProvider(_filters)),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _CaregiverCard(caregiver: list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.caregiver});

  final CaregiverProfileSummary caregiver;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () =>
          context.push('/marketplace/caregivers/${caregiver.profileId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                name: caregiver.name,
                photoUrl: caregiver.photoUrl,
                radius: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caregiver.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(caregiver.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RatingStars(rating: caregiver.rating),
              const SizedBox(width: 6),
              Text(
                '${caregiver.rating.toStringAsFixed(1)} (${caregiver.reviewsCount})',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (caregiver.pricePerHour != null)
                Text(
                  '\$${caregiver.pricePerHour!.toStringAsFixed(0)}/h',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
            ],
          ),
          if (caregiver.specialties.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in caregiver.specialties.take(3))
                  _Pill(label: s),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Productos
// ---------------------------------------------------------------------------
class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider(null));
    return products.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(productsProvider(null)),
      ),
      data: (list) => list.isEmpty
          ? const EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: 'Sin productos',
              subtitle: 'Aún no hay ayudas técnicas disponibles.',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(productsProvider(null)),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ProductCard(product: list[i]),
              ),
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final MarketProduct product;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              image: product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: product.imageUrl == null
                ? const Icon(Icons.medical_services_outlined,
                    color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(product.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  '\$${NumberFormat('#,##0', 'es').format(product.price)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trabajos (solo cuidadora)
// ---------------------------------------------------------------------------
class _JobsTab extends ConsumerWidget {
  const _JobsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    return jobs.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(jobsProvider),
      ),
      data: (list) => list.isEmpty
          ? const EmptyView(
              icon: Icons.work_outline_rounded,
              title: 'Sin ofertas',
              subtitle: 'Por ahora no hay ofertas de trabajo disponibles.',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(jobsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _JobCard(job: list[i]),
              ),
            ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobOffer job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(job.zone,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  size: 15, color: AppColors.secondary),
              const SizedBox(width: 4),
              Text(job.pay,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(job.description,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------
class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating.round()
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: 16,
            color: AppColors.statusWarning,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600)),
    );
  }
}
