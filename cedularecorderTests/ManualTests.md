# Manual Testing Checklist for AR Inspection App

## Pre-Release Manual Tests
**Device Required: iPhone 12 or newer with iOS 15+**

### 🎥 Core Recording Features
- [ ] **Start Recording**
  - Enter address "123 Test Street"
  - Tap "Start Recording" 
  - ✅ Camera preview appears
  - ✅ Recording indicator shows (red dot + timer)

- [ ] **AR Tracking Quality**
  - Move phone slowly around room
  - ✅ No freezing or stuttering
  - ✅ Tracking doesn't lose position

- [ ] **Stop & Save Recording**
  - Record for at least 30 seconds
  - Tap Stop button
  - ✅ Video saves without crash
  - ✅ File size is reasonable (>1MB for 30 sec)

### 🏠 Room Management
- [ ] **Add First Room**
  - During recording, tap "Add Room"
  - Select "Living Room"
  - ✅ Room appears in UI
  - ✅ Checklist shows for room

- [ ] **Switch Between Rooms**
  - Add second room (Kitchen)
  - Tap "Switch" button
  - Select different room
  - ✅ Checklist updates to show new room
  - ✅ Previous room progress is preserved

- [ ] **Room Progress Tracking**
  - Check 3 of 5 items in a room
  - ✅ Progress shows "3/5"
  - ✅ Status emoji changes from 🔴 to 🟡

### ✅ Checklist Features
- [ ] **Check Items During Recording**
  - Tap "Verified" button on checklist item
  - ✅ Item disappears, next item appears
  - ✅ Progress counter updates

- [ ] **Skip Questions**
  - Tap "Skip" on a checklist item
  - ✅ Shows next unchecked item
  - ✅ Skipped item remains unchecked

- [ ] **Complete All Items**
  - Check all items in one room
  - ✅ Shows "All checks completed" message
  - ✅ Room shows ✅ emoji

### 📏 AR Measurement Features
- [ ] **Enable Measurement Mode**
  - Tap ruler icon during recording
  - ✅ Button highlights in blue
  - ✅ "Measure" button appears

- [ ] **Add Measurement**
  - Tap "Measure" button
  - Tap first point on surface
  - Tap second point
  - ✅ Green circle at start point
  - ✅ Red circle at end point
  - ✅ Yellow line between points
  - ✅ Distance text shows (e.g., "2.5 m")

- [ ] **Measurements in Recording**
  - Add 2-3 measurements
  - Stop recording
  - Play back video
  - ✅ Measurements visible in saved video

### 📱 Video Playback
- [ ] **View Recorded Inspection**
  - Go back to inspection list
  - Tap on completed inspection
  - ✅ Video player opens
  - ✅ Video plays smoothly

- [ ] **Checklist Markers**
  - In video replay, tap checklist item
  - ✅ Video jumps to timestamp when item was checked
  - ✅ Playback continues from that point

- [ ] **Video Controls**
  - ✅ Play/pause works
  - ✅ Scrubbing works
  - ✅ Audio plays (if any)

### 🔄 App Lifecycle
- [ ] **Background/Foreground**
  - Start recording
  - Press home button (background app)
  - Return to app
  - ✅ Recording continues or handles gracefully
  - ✅ AR tracking resumes

- [ ] **Phone Call Interruption**
  - Start recording
  - Receive phone call (or simulate)
  - ✅ Recording pauses appropriately
  - ✅ Can resume or save after call

- [ ] **Low Memory Warning**
  - Record for 5+ minutes
  - Add multiple rooms
  - ✅ App doesn't crash
  - ✅ Shows warning if needed

### 📊 Data Integrity
- [ ] **Session Persistence**
  - Complete an inspection
  - Force quit app
  - Reopen app
  - ✅ Inspection still in list
  - ✅ All data preserved

- [ ] **Multiple Inspections**
  - Complete 3 inspections in one session
  - ✅ All show in list
  - ✅ Each has correct address
  - ✅ Can play each video

### 🚫 Edge Cases
- [ ] **Empty Address**
  - Try to start with blank address
  - ✅ Shows error or prevents start

- [ ] **No Camera Permission**
  - Deny camera permission in Settings
  - Open app
  - ✅ Shows appropriate message
  - ✅ Doesn't crash

- [ ] **Rapid Actions**
  - Quickly tap between rooms
  - Rapidly check/uncheck items
  - ✅ App remains stable
  - ✅ Data stays consistent

## Performance Benchmarks
Record these metrics for each device:

| Metric | Target | Actual |
|--------|--------|--------|
| App launch time | < 3 sec | _____ |
| Recording start time | < 2 sec | _____ |
| Room switch time | < 0.5 sec | _____ |
| Video save time (1 min) | < 5 sec | _____ |
| Memory usage (5 min recording) | < 200 MB | _____ |
| Battery drain (10 min recording) | < 10% | _____ |

## Device-Specific Tests

### iPhone 12/13 Mini
- [ ] UI elements fit on smaller screen
- [ ] Text is readable

### iPhone Pro Max
- [ ] UI scales appropriately
- [ ] No stretched elements

### iPad (if supported)
- [ ] Rotation works correctly
- [ ] UI adapts to larger screen

## Known Issues to Verify Fixed
- [ ] ~~Circle rendering uses triangleFan~~ → Now uses lineStrip
- [ ] ~~Pixel buffer locking issue~~ → Fixed with capture
- [ ] ~~ARRaycastQuery optional~~ → Fixed

## Final Checklist Before Release
- [ ] Test on physical device (not simulator)
- [ ] Test with real-world lighting conditions
- [ ] Test in different rooms/environments
- [ ] Verify no debug code remains
- [ ] Check no test data in production
- [ ] Confirm upload endpoints are production

---

**Testing Duration:** ~30 minutes for full suite
**Critical Path:** Recording → Add Room → Check Items → Stop → Playback
**Minimum Test:** Start/stop recording with one room