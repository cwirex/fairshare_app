import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/add_member_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/create_group_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/delete_group_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/remove_member_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/update_group_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_use_case_providers.g.dart';

@riverpod
CreateGroupUseCase createGroupUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return CreateGroupUseCase(repository);
}

@riverpod
UpdateGroupUseCase updateGroupUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return UpdateGroupUseCase(repository);
}

@riverpod
DeleteGroupUseCase deleteGroupUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return DeleteGroupUseCase(repository);
}

@riverpod
AddMemberUseCase addMemberUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return AddMemberUseCase(repository);
}

@riverpod
RemoveMemberUseCase removeMemberUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return RemoveMemberUseCase(repository);
}
