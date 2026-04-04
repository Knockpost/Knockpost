import 'package:flutter/material.dart';

class AudienceSelector extends StatelessWidget {
  final String selected;
  final Function(String) onChanged;

  const AudienceSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: const Text("Audience"),
      subtitle: Text(selected),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),

              _tile(context, "Private"),
              _tile(context, "Custom"),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, String value) {
    return ListTile(
      title: Text(value),
      onTap: () {
        onChanged(value);
        Navigator.pop(context);
      },
    );
  }
}
