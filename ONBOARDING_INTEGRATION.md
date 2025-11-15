# Onboarding Integration

## Overview
The onboarding screen is now integrated into the app's startup flow via `AuthWrapper`.

## Flow Sequence

```
App Launch
    ↓
Check Connectivity (ConnectivityProvider)
    ↓
    ├─ OFFLINE → NoConnectionScreen
    └─ ONLINE → Check Onboarding Status
                    ↓
                    ├─ NOT SEEN → OnboardingScreen (3 pages)
                    │                  ↓
                    │             User taps "Finish" or "Skip"
                    │                  ↓
                    │             Mark as seen (SharedPreferences)
                    │                  ↓
                    └─ SEEN → Check Authentication
                                  ↓
                                  ├─ LOADING → Loading Screen (with BikeAnimation)
                                  ├─ NOT AUTHENTICATED → LoginScreen
                                  └─ AUTHENTICATED → Home/Admin/Rider Dashboard
```

## Files Created/Modified

### Created:
- `lib/screens/onboarding_screen.dart` - The onboarding UI with 3 pages

### Modified:
- `lib/screens/auth_wrapper.dart` - Added onboarding check logic

## Key Features

1. **One-Time Display**: Onboarding shows only on first app launch
2. **Persistent State**: Uses SharedPreferences to remember if user has seen it
3. **Skip Option**: Users can skip directly to login
4. **Beautiful UI**: 3 themed pages with animations and smooth transitions
5. **Proper Flow**: Onboarding → Login → Home (respects auth state)

## Testing Onboarding

To see the onboarding again during development:

### Method 1: Clear App Data (Recommended)
```bash
# Android
flutter run --clear-app-data

# Or manually:
adb shell pm clear com.yourapp.package
```

### Method 2: Reset via Code (Add to Profile/Settings)
```dart
// In your profile screen or settings, add a developer option:
TextButton(
  onPressed: () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_onboarding');
    // Then restart the app or navigate to AuthWrapper
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  },
  child: const Text('Reset Onboarding (Dev Only)'),
)
```

## Onboarding Pages

### Page 1: Local Flavor
- **Color**: Primary Orange (#d75b47)
- **Message**: "Savor the Taste of Home"
- **Focus**: Authentic African & local delicacies

### Page 2: Fast Delivery
- **Color**: Green (#1eb090)
- **Message**: "Delivered Fresh, Fast, and Hot"
- **Focus**: Real-time tracking & reliability

### Page 3: Easy Ordering
- **Color**: Yellow (#feae4f)
- **Message**: "Find Your Next Favorite Meal"
- **Focus**: Bookmarks, history, reordering

## Customization

To modify the onboarding content, edit `lib/screens/onboarding_screen.dart`:

```dart
OnboardingPageModel(
  title: 'Your Title',
  description: 'Your description text',
  imageUrl: 'https://your-image-url.com/image.png',
  bgColor: YourColors.custom,
  textColor: Colors.white,
),
```

## Notes

- Onboarding is checked **before** authentication
- Uses existing connectivity check infrastructure
- No backend calls required (local SharedPreferences only)
- Compatible with existing auth flow (login → role-based routing)
