# Info.plist Privacy Usage Description Strings

Add these keys to your app's **Info.plist** (or target → Info tab in Xcode). They appear in the iOS permission prompt shown to the user.

---

## Required

### NSPhotoLibraryUsageDescription
```
Travel Journal AI reads your photo albums to import images, captions, and GPS locations for your travel journal. Your photos are processed entirely on device.
```

---

## How to add in Xcode

1. Select the **TravelJournalAI** target in the project navigator.
2. Click the **Info** tab.
3. Hover over any row and click **+** to add a new row.
4. Type the key name (Xcode will autocomplete it as "Privacy - Photo Library Usage Description").
5. Set the value to the string above.

Alternatively, right-click `Info.plist` in the navigator → **Open As → Source Code** and paste:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Travel Journal AI reads your photo albums to import images, captions, and GPS locations for your travel journal. Your photos are processed entirely on device.</string>
```

---

## Notes

- **Location permission (NSLocationWhenInUseUsageDescription) is NOT required.** The app reads GPS from photo EXIF metadata via the Photos framework, not from the device location services. Do not add a location usage string — requesting permission you don't need can cause App Review rejection.
- **NSPhotoLibraryAddUsageDescription is NOT required.** The app only reads the library; it does not save new photos.
- **Face ID / camera / microphone are NOT used.** No additional usage strings needed.

---

## PrivacyInfo.xcprivacy

The file `PrivacyInfo.xcprivacy` already exists at the root of the repo. You need to add it to the Xcode project target:

1. In Xcode, **File → Add Files to "TravelJournalAI"…**
2. Select `PrivacyInfo.xcprivacy`.
3. Make sure **"Add to target: TravelJournalAI"** is ticked.
4. Click **Add**.

Xcode 16+ recognises `.xcprivacy` files automatically and includes them in the app bundle.
