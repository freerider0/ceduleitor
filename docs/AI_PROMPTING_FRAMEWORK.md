# AI Prompting Framework: Getting Simple, Maintainable Code

## The Blueprint Prompting Sequence

Follow this EXACT sequence for each feature:

## PHASE 1: RESEARCH (Understand Concepts)

### Prompt 1.1: Learn the Basics
```
"What's the simplest way to [FEATURE] in iOS using [FRAMEWORK]?
Show me the minimal code pattern - under 30 lines if possible.
Explain what each part does."
```

**Example:**
```
"What's the simplest way to detect walls in iOS using ARKit?
Show me the minimal code pattern - under 30 lines if possible.
Explain what each part does."
```

### Prompt 1.2: Understand Requirements
```
"For iOS [FEATURE], what are the essential components I need?
- What delegates/protocols?
- What UI components?
- What permissions?
List only what's absolutely required."
```

## PHASE 2: DESIGN (Create Blueprint)

### Prompt 2.1: Write Your Design
Create a simple blueprint (10-30 lines) describing WHAT you want:

```sudolang
[AppName] v[0.X] {
  Features {
    [ONE feature for this version]
  }

  Events {
    [User actions or system callbacks]
  }

  Constraints {
    * Under [X] lines total
    * Use only built-in iOS components
    * No custom systems or managers
  }
}
```

### Prompt 2.2: Validate Design
```
"Review this blueprint for an iOS app:
[YOUR BLUEPRINT]

Check for:
1. Is this the simplest approach?
2. Am I missing any iOS requirements?
3. Can anything be removed?"
```

## PHASE 3: IMPLEMENT (Convert to Code)

### Prompt 3.1: Initial Implementation
```
"Convert this blueprint to iOS Swift code:
[PASTE YOUR BLUEPRINT]

Requirements:
- Use ONLY built-in iOS/[FRAMEWORK] components
- NO custom systems, managers, or coordinators beyond what's specified
- Each file under 150 lines
- Minimal code that just works
- No error handling beyond optionals
- No comments

Output files:
1. [AppName].swift - SwiftUI app entry (20 lines max)
2. [MainView].swift - Main UI (50 lines max)
3. [Logic].swift - Core logic (100 lines max)"
```

### Prompt 3.2: Simplification Pass
```
"This iOS code is too complex. Simplify it:
[PASTE CODE]

Requirements:
- Remove any unnecessary abstractions
- Combine files if under 150 lines
- Use built-in iOS features instead of custom code
- Remove any 'future-proofing'
- Make it readable for a junior developer"
```

## PHASE 4: EXTEND (Add Features One at a Time)

### Prompt 4.1: Add Single Feature
```
"Add ONE feature to this existing code:

Current blueprint:
[CURRENT BLUEPRINT]

New feature to add:
[SINGLE NEW FEATURE]

Requirements:
- Minimal change to existing code
- Keep total under [X] lines
- No refactoring unless absolutely necessary
- Just make it work"
```

## Power Prompts (Copy & Paste Ready)

### When Starting New Feature
```
"What's the absolute minimum iOS code to [FEATURE]?
Show example under 50 lines.
No abstractions, just working code."
```

### When AI Overengineers
```
"This is overengineered. Rewrite it:
- No systems or managers
- One file if possible
- Under 100 lines
- Direct implementation only
- Use built-in iOS features"
```

### When You're Lost
```
"Explain what each part of this iOS code does:
[paste code]

Focus on:
- Why is each part necessary?
- What could be removed?
- What iOS feature handles this?"
```

### When AI Creates Too Many Files
```
"Combine these files into fewer files:
[list files]

Rules:
- Each file max 150 lines
- Group related functionality
- Remove unnecessary abstractions"
```

### When You Need Pure iOS
```
"Show me how Apple would implement this in their sample code.
Use only native iOS APIs.
No third-party patterns.
Maximum simplicity."
```

## The Magic Phrases That Trigger Simple Code

Use these phrases to get simpler output:

- "Minimal viable"
- "Quick and dirty"
- "Prototype version"
- "No abstractions"
- "Direct implementation"
- "Built-in only"
- "Single file if possible"
- "Like Apple's sample code"
- "Hackathon style"
- "Under 100 lines"

## Example: Complete Feature Addition

### Week 1: Just Camera
```
Research: "Simplest way to show AR camera in iOS?"
Blueprint:
  ARApp v0.1 { show AR camera }
Implement: "Convert to Swift. Under 50 lines."
```

### Week 2: Add Detection
```
Research: "How does ARSessionDelegate work?"
Blueprint:
  ARApp v0.2 {
    previous + detect planes (log only)
  }
Implement: "Add plane detection. Log to console. Minimal change."
```

### Week 3: Add Visuals
```
Blueprint:
  ARApp v0.3 {
    previous + tap to show green wall
  }
Implement: "Add tap to show walls. Keep simple."
```

## Red Flag Responses from AI

If AI responds with any of these, IMMEDIATELY ask for simplification:

- "Here's a robust solution..." → "Make it simpler"
- "I'll create a manager class..." → "No managers, direct implementation"
- "For better architecture..." → "Keep it simple, no architecture"
- "This follows best practices..." → "Just make it work, minimal code"
- "I'll add error handling..." → "No error handling beyond optionals"

## The Golden Rule

> Every prompt should include constraints:
> - Line limit
> - No systems/managers
> - Use built-in features
> - Direct implementation

## Progressive Prompt Example

```
Day 1: "Simplest AR camera?" (10 lines)
Day 2: "Add plane detection?" (+20 lines)
Day 3: "Add tap to select?" (+20 lines)
Day 4: "Add measurement?" (+30 lines)
Total: 80 lines of understood code
```

## Remember

The best prompt is the one that gets you code you can understand and modify. If AI gives you something complex, it's not AI's fault - refine your prompt with more constraints!