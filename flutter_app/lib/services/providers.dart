import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doqr_api.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final doqrApiProvider = Provider<DoqrApi>((ref) => DoqrApi(ref.read(supabaseProvider)));
