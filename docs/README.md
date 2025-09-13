# AR Development Documentation

## How to Build AR Apps Without Overengineering

This documentation captures a complete methodology for building maintainable AR applications using AI assistance while avoiding the common trap of overengineered, unmaintainable code.

## The Problem This Solves

When using AI to generate code:
- Day 1: "Wow, AI is so fast!"
- Day 3: Everything breaks, nobody understands the code
- Day 5: Even AI can't fix its own mess

This framework prevents that collapse.

## Documentation Structure

### 📚 Core Philosophy
- **[DEVELOPMENT_PHILOSOPHY.md](DEVELOPMENT_PHILOSOPHY.md)** - The fundamental principles and rules
  - The three golden rules
  - Progressive development approach
  - When to add complexity (rarely)

### 🤖 AI Usage
- **[AI_PROMPTING_FRAMEWORK.md](AI_PROMPTING_FRAMEWORK.md)** - How to prompt AI for simple code
  - The blueprint prompting sequence
  - Power prompts that work
  - Red flags in AI responses

### 📝 Design First
- **[SUDOLANG_AR_GUIDE.md](SUDOLANG_AR_GUIDE.md)** - Using SudoLang to design before coding
  - How to write blueprints
  - iOS/AR specific patterns
  - Progressive feature development

### 🧪 Testing
- **[TESTING_WITHOUT_MOCKS.md](TESTING_WITHOUT_MOCKS.md)** - Real tests without mock theater
  - Why mocks test nothing
  - What to test (calculations)
  - What to skip (iOS frameworks)

### 📱 AR Implementation
- **[AR_IMPLEMENTATION_GUIDE.md](AR_IMPLEMENTATION_GUIDE.md)** - Building AR apps the simple way
  - Essential iOS/AR concepts
  - Progressive development plan
  - Common features in <100 lines

### ⚡ Quick Reference
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - One-page cheat sheet
  - All power prompts
  - Red flags checklist
  - Daily workflow

## How to Use This Documentation

### If You're Starting a New AR Project

1. **Read [QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Print it, pin it to your wall
2. **Follow [AR_IMPLEMENTATION_GUIDE.md](AR_IMPLEMENTATION_GUIDE.md)** - Start with 30 lines
3. **Use [AI_PROMPTING_FRAMEWORK.md](AI_PROMPTING_FRAMEWORK.md)** - Get simple implementations

### If You're Fighting Overengineered Code

1. **Read [DEVELOPMENT_PHILOSOPHY.md](DEVELOPMENT_PHILOSOPHY.md)** - Understand the principles
2. **Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Look for red flags
3. **Start over with v0.1** - 30 lines that work

### If You Want to Add Features

1. **Use [SUDOLANG_AR_GUIDE.md](SUDOLANG_AR_GUIDE.md)** - Design first
2. **Follow [AI_PROMPTING_FRAMEWORK.md](AI_PROMPTING_FRAMEWORK.md)** - Phase 4
3. **One feature at a time** - Ship weekly

### If You Need to Test

1. **Read [TESTING_WITHOUT_MOCKS.md](TESTING_WITHOUT_MOCKS.md)**
2. **Test calculations only** - Skip iOS frameworks
3. **5 tests maximum** - For entire app

## The Core Methodology

```
LEARN → DESIGN → BUILD → SHIP → REPEAT
  ↑                              ↓
  └──────── Stay Simple ─────────┘
```

## Key Principles

1. **One Feature Per Week** - Ship every Friday
2. **Under 150 Lines Per File** - No exceptions
3. **No Mocks in Tests** - Test behavior, not mocks
4. **No Custom Systems** - RealityKit already has them
5. **Delete Unclear Code** - If you can't explain it, delete it

## Example: Your First Week

### Monday
```bash
# Read the quick reference
cat docs/QUICK_REFERENCE.md

# Learn ARKit basics
"What's the simplest way to show AR camera?"
```

### Tuesday
```sudolang
# Design v0.1
ARApp v0.1 {
  Features { Show AR camera }
  Constraints { Under 50 lines }
}
```

### Wednesday
```bash
# Build
"Convert this SudoLang to Swift. No extras."
```

### Thursday
```bash
# Test manually (no unit tests yet)
# Run on device
```

### Friday
```bash
# Ship to TestFlight
# You have working AR app in 50 lines!
```

## Common Mistakes to Avoid

❌ Starting with complex architecture
✅ Start with 30 lines

❌ Adding multiple features at once
✅ One feature per week

❌ Writing elaborate test mocks
✅ Test calculations only

❌ Creating Manager/System classes
✅ Direct implementation

❌ Keeping code you don't understand
✅ Delete and rewrite simpler

## Success Metrics

You're doing it right if:
- Shipping weekly
- Under 1000 lines after month 1
- Zero "Manager" classes
- Can explain every line
- Adding features is easy

## Remember

> "The best code is the code you understand."

> "Ship 100 working lines, not debug 1000 broken lines."

> "Senior developers write simple code."

## Getting Help

When stuck, ask AI:
1. "How can this be simpler?"
2. "What can I delete?"
3. "Show me Apple's way"

Then check against [QUICK_REFERENCE.md](QUICK_REFERENCE.md) red flags.

---

**Start with [QUICK_REFERENCE.md](QUICK_REFERENCE.md). Build something simple today.**