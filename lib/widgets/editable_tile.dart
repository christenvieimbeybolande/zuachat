import 'package:flutter/material.dart';

class EditableTile extends StatefulWidget {
  final String label;
  final Widget display;
  final Widget editor;
  final Future<void> Function() onSave;

  const EditableTile({
    super.key,
    required this.label,
    required this.display,
    required this.editor,
    required this.onSave,
  });

  @override
  State<EditableTile> createState() => _EditableTileState();
}

class _EditableTileState extends State<EditableTile> {
  bool _editing = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 HEADER
            Row(
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                if (!_editing)
                  TextButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('Modifier'),
                  ),
              ],
            ),

            // 🔹 CONTENT
            if (!_editing)
              widget.display
            else ...[
              widget.editor,
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => setState(() => _editing = false),
                    child: const Text('Annuler'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await widget.onSave();
                            setState(() {
                              _saving = false;
                              _editing = false;
                            });
                          },
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
