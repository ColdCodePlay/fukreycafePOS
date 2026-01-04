import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: userProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            // Should not happen if auth guard works, but maybe profile fetch failed?
            return const Center(child: Text('Unable to load profile.'));
          }

          // ** AUTO-REDIRECT LOGIC **
          // We use Future.microtask to avoid build-phase navigation errors
          if (profile.role == 'admin') {
             Future.microtask(() => { if (context.mounted) context.go('/admin') });
             return const Center(child: CircularProgressIndicator());
          } else if (profile.role == 'staff') {
             Future.microtask(() => { if (context.mounted) context.go('/pos') });
             return const Center(child: CircularProgressIndicator());
          }
          
          return const Center(child: Text('Unknown Role'));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $e'),
            ElevatedButton(
              onPressed: () => ref.read(authControllerProvider.notifier).logout(), 
              child: const Text('Logout')
            )
          ],
        )),
      ),
    );
  }
}
