import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static const String _kMoodKey = 'pref_mood';
  static const String _kRoomKey = 'pref_room_type';

  static Future<void> saveDetectedPreferences(String? mood, String? roomType) async {
    final prefs = await SharedPreferences.getInstance();
    if (mood != null) await prefs.setString(_kMoodKey, mood);
    if (roomType != null) await prefs.setString(_kRoomKey, roomType);
  }

  static Future<Map<String, String?>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'mood': prefs.getString(_kMoodKey),
      'roomType': prefs.getString(_kRoomKey),
    };
  }

  // Helper to extract keywords from AI text or user input
  static void updateFromText(String text) {
    String? detectedMood;
    String? detectedRoom;

    final lower = text.toLowerCase();
    
    // Mood Detection
    if (lower.contains('calm') || lower.contains('relax')) detectedMood = 'Calm';
    if (lower.contains('warm') || lower.contains('cozy')) detectedMood = 'Warm';
    if (lower.contains('luxury') || lower.contains('elegant')) detectedMood = 'Luxury';
    if (lower.contains('modern') || lower.contains('minimal')) detectedMood = 'Modern';
    if (lower.contains('energetic') || lower.contains('bright')) detectedMood = 'Energetic';

    // Room Detection
    if (lower.contains('living')) detectedRoom = 'Living Room';
    if (lower.contains('bedroom')) detectedRoom = 'Bedroom';
    if (lower.contains('kitchen')) detectedRoom = 'Kitchen';
    if (lower.contains('office')) detectedRoom = 'Office';
    if (lower.contains('dining')) detectedRoom = 'Dining Room';
    if (lower.contains('kids')) detectedRoom = 'Kids Room';

    if (detectedMood != null || detectedRoom != null) {
      saveDetectedPreferences(detectedMood, detectedRoom);
    }
  }
}
