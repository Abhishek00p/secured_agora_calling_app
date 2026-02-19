// import 'package:flutter/material.dart';

// class CustomDropdown extends StatefulWidget {
//   final List<String> items;
//   final String value;
//   final ValueChanged<String> onChanged;

//   const CustomDropdown({
//     Key? key,
//     required this.items,
//     required this.value,
//     required this.onChanged,
//   }) : super(key: key);

//   @override
//   State<CustomDropdown> createState() => _CustomDropdownState();
// }

// class _CustomDropdownState extends State<CustomDropdown> {
//   final LayerLink _layerLink = LayerLink();
//   OverlayEntry? _overlayEntry;

//   void _toggleDropdown() {
//     if (_overlayEntry == null) {
//       _overlayEntry = _createOverlayEntry();
//       Overlay.of(context).insert(_overlayEntry!);
//     } else {
//       _overlayEntry?.remove();
//       _overlayEntry = null;
//     }
//   }
//   OverlayEntry _createOverlayEntry() {
//   RenderBox renderBox = context.findRenderObject() as RenderBox;
//   Size size = renderBox.size;
//   Offset offset = renderBox.localToGlobal(Offset.zero);

//   double screenHeight = MediaQuery.of(context).size.height;
//   double availableBelow = screenHeight - (offset.dy + size.height);
//   double availableAbove = offset.dy;
//   double dropdownHeight = 300.0; // your fixed desired height

//   bool showAbove = availableBelow < dropdownHeight && availableAbove >= dropdownHeight;

//   return OverlayEntry(
//     builder: (context) => Positioned(
//       width: 150, // the dropdown popup width
//       left: offset.dx,
//       top: showAbove
//           ? offset.dy - dropdownHeight
//           : offset.dy + size.height,
//       child: Material(
//         elevation: 4.0,
//         child: ConstrainedBox(
//           constraints: BoxConstraints(
//             maxHeight: dropdownHeight,
//           ),
//           child: ListView(
//             padding: EdgeInsets.zero,
//             shrinkWrap: true,
//             children: widget.items.map((item) {
//               return ListTile(
//                 title: Text(item),
//                 onTap: () {
//                   widget.onChanged(item);
//                   _toggleDropdown();
//                 },
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     ),
//   );
// }

//   @override
//   Widget build(BuildContext context) {
//     return CompositedTransformTarget(
//       link: _layerLink,
//       child: GestureDetector(
//         onTap: _toggleDropdown,
//         child: Container(
//           width: double.infinity,
//           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey),
//             borderRadius: BorderRadius.circular(4),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(widget.value),
//               Icon(Icons.arrow_drop_down),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
