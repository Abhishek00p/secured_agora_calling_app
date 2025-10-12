import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formats a DateTime object into a string like "Dec 25, 2024 at 2:30 PM"
String formatDateTime(DateTime dateTime) {
  return DateFormat('MMM d, yyyy \'at\' h:mm a').format(dateTime);
}

/// Formats a Duration object into a string like "1h 30m"
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  String result = '';
  if (hours > 0) {
    result += '${hours}h ';
  }
  if (minutes > 0 || hours == 0) {
    result += '${minutes}m';
  }
  return result.trim();
}

/// Extracts the first letter of a name and capitalizes it.
String getInitial(String name) {
  if (name.trim().isEmpty) {
    return '?';
  }
  return name.trim()[0].toUpperCase();
}

/// Provides a consistent color from a predefined list based on an index.
/// Useful for getting varied colors for avatars.
Color getAvatarColor(int index) {
  final List<Color> materialColors = [
    Colors.red[400]!,
    Colors.pink[400]!,
    Colors.purple[400]!,
    Colors.deepPurple[400]!,
    Colors.indigo[400]!,
    Colors.blue[400]!,
    Colors.lightBlue[400]!,
    Colors.cyan[400]!,
    Colors.teal[400]!,
    Colors.green[400]!,
    Colors.lightGreen[400]!,
    Colors.amber[400]!,
    Colors.orange[400]!,
    Colors.deepOrange[400]!,
    Colors.brown[400]!,
    Colors.blueGrey[400]!,
  ];
  return materialColors[index % materialColors.length];
}

/// Builds a styled Chip widget to display the meeting status.
Widget buildStatusChip(String status) {
  Color chipColor;
  String chipLabel;
  IconData iconData;

  switch (status.toLowerCase()) {
    case 'ongoing':
      chipColor = Colors.green;
      chipLabel = 'Ongoing';
      iconData = Icons.videocam;
      break;
    case 'upcoming':
      chipColor = Colors.blue;
      chipLabel = 'Upcoming';
      iconData = Icons.event;
      break;
    case 'ended':
      chipColor = Colors.grey;
      chipLabel = 'Ended';
      iconData = Icons.videocam_off;
      break;
    default:
      chipColor = Colors.black;
      chipLabel = 'Unknown';
      iconData = Icons.help_outline;
  }

  return Chip(
    avatar: Icon(iconData, color: Colors.white, size: 16),
    label: Text(chipLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    backgroundColor: chipColor,
    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
  );
}
