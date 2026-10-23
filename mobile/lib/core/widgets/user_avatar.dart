import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/profile_avatars.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.url,
    this.name,
    this.radius = 24,
    this.onTap,
  });

  final String? url;
  final String? name;
  final double radius;
  final VoidCallback? onTap;

  String get _fallbackInitial =>
      name == null || name!.trim().isEmpty
          ? '?'
          : name!.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final asset = ProfileAvatars.assetPath(url);
    final resolved = asset == null ? AppConfig.resolveAssetUrl(url) : '';
    final avatar = Ink(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        foregroundImage:
            asset != null
                ? AssetImage(asset)
                : resolved.isEmpty
                ? null
                : CachedNetworkImageProvider(resolved),
        onForegroundImageError:
            asset != null || resolved.isNotEmpty
                ? (error, stackTrace) {}
                : null,
        child: Text(
          _fallbackInitial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }
}

class CallProfile extends StatelessWidget {
  const CallProfile({
    super.key,
    this.url,
    this.name,
    this.bio,
    this.radius = 24,
    this.onTap,
  });

  final String? url;
  final String? name;
  final String? bio;
  final double radius;
  final VoidCallback? onTap;

  String get _fallbackInitial =>
      name == null || name!.trim().isEmpty
          ? '?'
          : name!.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final asset = ProfileAvatars.assetPath(url);
    final resolved = asset == null ? AppConfig.resolveAssetUrl(url) : '';
    final avatar = Ink(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        foregroundImage:
            asset != null
                ? AssetImage(asset)
                : resolved.isEmpty
                ? null
                : CachedNetworkImageProvider(resolved),
        onForegroundImageError:
            asset != null || resolved.isNotEmpty
                ? (error, stackTrace) {}
                : null,
        child: Text(
          _fallbackInitial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: avatar,
        ),
        Text(
          name!,
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(bio!, style: TextStyle(color: Colors.black, fontSize: 14)),
      ],
    );
  }
}
