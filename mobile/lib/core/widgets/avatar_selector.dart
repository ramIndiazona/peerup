import 'package:flutter/material.dart';

import '../config/profile_avatars.dart';
import 'user_avatar.dart';

class AvatarSelector extends StatelessWidget {
  const AvatarSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String? selected;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children:
          ProfileAvatars.ids.map((id) {
            final isSelected = selected == id;
            return Semantics(
              label: 'Avatar ${ProfileAvatars.ids.indexOf(id) + 1}',
              selected: isSelected,
              button: true,
              child: InkWell(
                key: ValueKey(id),
                customBorder: const CircleBorder(),
                onTap: onSelected == null ? null : () => onSelected!(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected
                              ? primary
                              : Theme.of(context).colorScheme.outlineVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(child: UserAvatar(url: id)),
                      if (isSelected)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: primary,
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
