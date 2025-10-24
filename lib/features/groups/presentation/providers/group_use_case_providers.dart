import 'package:fairshare_app/core/sync/sync_providers.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/add_member_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/create_group_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/delete_group_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/group_use_case_interfaces.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/join_group_by_code_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/remove_member_use_case.dart';
import 'package:fairshare_app/features/groups/domain/use_cases/update_group_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_use_case_providers.g.dart';

@riverpod
ICreateGroupUseCase createGroupUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return CreateGroupUseCase(repository);
}

@riverpod
IUpdateGroupUseCase updateGroupUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return UpdateGroupUseCase(repository);
}

@riverpod
IDeleteGroupUseCase deleteGroupUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return DeleteGroupUseCase(repository);
}

@riverpod
IAddMemberUseCase addMemberUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return AddMemberUseCase(repository);
}

@riverpod
IRemoveMemberUseCase removeMemberUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return RemoveMemberUseCase(repository);
}

/// Provider for JoinGroupByCode
/// This use case orchestrates both local repository and remote service
@riverpod
IJoinGroupByCodeUseCase joinGroupByCodeUseCase(Ref ref) {
  final repository = ref.watch(groupRepositoryProvider);
  final remoteService = ref.watch(remoteGroupServiceProvider);
  return JoinGroupByCodeUseCase(repository, remoteService);
}
