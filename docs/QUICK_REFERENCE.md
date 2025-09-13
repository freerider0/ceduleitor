# Quick Reference: Anti-Overengineering Cheat Sheet

## The Framework in One Page

```
LEARN (ask AI) → DESIGN (SudoLang) → BUILD (AI implements) → SHIP IT
```

## Three Golden Rules
1. **One Feature at a Time** - Never add 2+ features together
2. **Under 150 Lines per File** - Can't fit? You're overengineering
3. **If You Can't Explain It, Delete It** - Every line must make sense

## The Power Prompts

### Research Phase
```
"What's the simplest way to [FEATURE] in iOS?
Show minimal example under 50 lines."
```

### Design Phase (SudoLang)
```sudolang
AppName v0.X {
  Features { [ONE thing] }
  Constraints {
    * Under X lines
    * No systems/managers
  }
}
```

### Implementation Phase
```
"Convert this SudoLang to Swift.
No extras. No managers. Under X lines."
```

### When AI Overengineers
```
"Too complex. Simplify:
- Remove abstractions
- One file if possible
- Direct implementation"
```

## Red Flags = STOP

🚩 File over 150 lines → Split or simplify
🚩 Words: Manager, System, Factory → Delete
🚩 Can't explain it → Delete
🚩 AI generates 500+ lines → Start over

## Progressive Development

```
Week 1: v0.1 - Camera only (30 lines)
Week 2: v0.2 - Add detection (60 lines)
Week 3: v0.3 - Add interaction (100 lines)
Week 4: v1.0 - Add measurement (150 lines)
```

## iOS/AR Essential Concepts

### What You Need
- ARSessionDelegate - Get plane events
- UIViewRepresentable - Bridge to SwiftUI
- ObservableObject - Update UI
- Gesture Recognizers - Handle taps

### What You DON'T Need
- Custom Systems - RealityKit has them
- Managers - Direct implementation
- Mocks - Test calculations instead
- Abstractions - Use built-in iOS

## Testing Without Mocks

### Test These
```swift
// Pure functions only
func test_DistanceCalc() {
    XCTAssertEqual(distance(a,b), 5.0)
}
```

### Skip These
```swift
// Don't test iOS frameworks
// Don't mock ARSession
// Don't test delegates
```

## File Structure Target

```
App.swift (20 lines)
ContentView.swift (50 lines)
Coordinator.swift (100 lines)
Models.swift (30 lines)
---
Total: 200 lines
```

## The Daily Workflow

### Morning
```
Ask: "How does [X] work in iOS?"
Learn: Understand the concept
```

### Afternoon
```
Design: 10 lines of SudoLang
Build: AI implements
Test: Does it work?
```

### Evening
```
Ship: Push to TestFlight
Sleep: You understand everything!
```

## Magic Phrases for Simple Code

Use these in every prompt:
- "Minimal viable"
- "Under X lines"
- "No abstractions"
- "Direct implementation"
- "Like Apple's sample code"

## Decision Tree

```
Can you explain it? → No → Delete it
Is it over 150 lines? → Yes → Split it
Does it have "Manager"? → Yes → Remove it
Are there mocks? → Yes → Delete tests
Does it work? → Yes → Ship it!
```

## Complete Example Prompt

```
"Convert this to iOS Swift:

Features:
- Detect AR planes
- Tap to highlight

Requirements:
- Under 100 lines total
- No systems or managers
- Use only RealityKit built-ins
- Direct implementation
- Single file if possible"
```

## Remember

- **Start simple** (30 lines)
- **Add one feature** (ship it)
- **Repeat weekly** (not monthly)
- **Stay under 1000 lines** (first month)
- **Delete "might need it"** code

## The Bottom Line

```
Simple code you understand > Complex code that "might be better"

Ship Friday with 100 working lines
NOT
Debug Monday with 1000 broken lines
```

## Emergency Fixes

### When Lost
```
"Explain what this does and why it's needed"
```

### When Complex
```
"Make this simpler - remove all abstractions"
```

### When Broken
```
Start over with v0.1 - just camera (30 lines)
```

---

**Print this page. Pin it to your wall. Follow it religiously.**