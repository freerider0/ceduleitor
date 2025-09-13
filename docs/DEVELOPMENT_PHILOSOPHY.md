# Development Philosophy: Building Apps That Don't Collapse

## The Core Problem

AI-generated code tends to overengineer simple problems, leading to:
- Day 1: "Wow, AI is so fast!"
- Day 3: Everything breaks
- Day 5: Nobody understands the code (not even AI)

## The Solution: Three Rules + Three Steps

### The Three Golden Rules (ALWAYS FOLLOW)

#### 1. One Feature at a Time
```
Monday: Just detect walls
Tuesday: Just add tapping
Wednesday: Just add measurements
NEVER: Everything at once
```

#### 2. Under 150 Lines per File
- Can't fit? Split into logical pieces
- Still can't fit? You're overengineering
- Exception: Only for complex algorithms with extensive comments

#### 3. If You Can't Explain It, Delete It
- Every line must make sense to you
- No "magic" code from AI
- No keeping code because "might need it later"

### The Three Steps (FOR EACH FEATURE)

#### Step 1: LEARN (30% of time)
Ask AI to explain concepts before coding:
```
"What's the simplest way to detect AR planes in iOS?"
"Show me minimal example under 50 lines"
"Explain what ARSessionDelegate does"
```

#### Step 2: DESIGN (20% of time)
Write simple blueprint in SudoLang or pseudocode:
```sudolang
WallDetector {
  detect planes -> store them
  tap wall -> make it green

  constraints:
    * Under 100 lines
    * Use only built-in iOS
}
```

#### Step 3: BUILD (50% of time)
Have AI implement YOUR design:
```
"Implement this exact blueprint in Swift.
 No extras. No systems. No managers."
```

## Red Flags That Mean STOP

🚩 **Immediate Stop Signs:**
- File over 150 lines
- Words like: Manager, System, Coordinator, Factory, Repository
- Multiple abstraction layers
- Can't explain what something does
- Adding 2+ features at once
- AI generates 500+ lines for simple feature

**When you see these → STOP → Simplify → Start over**

## The Reality of Complex Apps

Complex apps are NOT built in one shot. They EVOLVE:

- WhatsApp started as status updates
- Instagram started without videos
- Facebook started without news feed
- Uber started without real-time tracking

Your app should:
1. Start with minimal viable feature (ship it)
2. Add ONE feature per week (ship each)
3. Refactor only when it becomes painful (not before)
4. Stay under 1000 lines for first month
5. Understand EVERY line

## Architecture Philosophy

### Start Simple
```
Week 1: App.swift (30 lines)
Week 2: App.swift + WallDetector.swift (100 lines)
Week 3: Split only when files exceed 150 lines
```

### Add Complexity Only When Needed
Add abstractions ONLY when:
- You've copied same code 3+ times
- Single file over 300 lines
- You NEED it today (not tomorrow)
- You understand why

NOT because:
- "Might need it later"
- "This is how pros do it"
- "AI suggested it"
- "Seems more flexible"

## The Daily Workflow

### Morning (30 min)
- LEARN: "How does [feature] work in iOS?"
- Understand the concept
- Look at Apple's examples

### Afternoon (2 hours)
- DESIGN: Write 10-20 lines of SudoLang
- BUILD: AI implements your design
- TEST: Does it work?

### Evening
- SHIP: Push working version
- CELEBRATE: You understand your code!

## Using AI Effectively

### AI is Great For:
- Explaining concepts
- Showing API examples
- Syntax help
- Small function implementation
- Bug explanations

### AI is Terrible For:
- System architecture
- Design decisions
- Complex abstractions
- "Professional" patterns
- Complete applications

## The Success Metrics

### ✅ You're Succeeding If:
- Shipped feature this week
- Code under 150 lines per file
- Zero "manager" classes
- Can explain every line to someone else
- Can modify without fear
- Tests are simple and minimal

### ❌ You're Failing If:
- Week 2 still debugging same feature
- 500+ lines in a file
- Multiple abstraction layers
- Scared to touch the code
- AI can't help anymore
- More test code than app code

## Remember

> "The goal isn't to write code fast, it's to write code you can maintain."

> "A simple 50-line solution you understand beats a 500-line 'professional' system that becomes a black box."

> "Senior developers write SIMPLE code. AI often writes like someone trying to impress in an interview."

## The Bottom Line

Build simple version → Use it → Find real problems → Add ONE solution → Repeat

This is how sustainable software is built.