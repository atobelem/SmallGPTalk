# SmallGPTalk development rules

## Fresh implementation

This directory is a rewrite from zero, not a migration or refactor.
The old implementation is a reference, not the starting class model.
Do not copy its classes, tests, or architecture as the new implementation.
Start with executable Smalltalk examples and behavior tests. Let the object
collaborations guide the classes. Use composition and small protocols.
Consult the old login and transport code for verified protocol details.
Port code only after its role in the new design is clear and tested.

## Project direction

- Build a minimal agent harness in Smalltalk for Pharo.
- Treat Pi Coding Agent as the main design reference.
- Read the design principles in [README.md](README.md) before a design change.
- Keep the first version focused on OpenAI models with account login.
- Preserve login in macOS Keychain across Pharo restarts.
- Keep the Smalltalk API independent of the optional chat window.
- Use Playground examples and headless tests before adding a user interface.
- Start with evaluate as the only image tool. Use Smalltalk for reflection, code changes, and SUnit.
- Keep file tools, shell tools, and session storage outside the first version.
- Preserve the account login requirement when a connection problem occurs.
- Keep planned features distinct from implemented features.

## Design and code

- Implement the agent loop in Smalltalk.
- Prefer small objects, short methods, and explicit protocols.
- Use composition when it keeps responsibilities clear.
- Keep provider details outside the agent loop.
- Keep interface details outside the agent loop.
- Keep conversation and tool state easy to inspect in Pharo.
- Add a core feature only when the basic agent loop needs it.
- Keep extra behavior in extensions.
- Add abstractions and dependencies only for current requirements.
- Use Tonel for source files and Metacello for package dependencies.
- Use SUnit to test behavior when executable code is added.
- Keep ordinary unit tests independent of live OpenAI access.
- Keep ordinary unit tests independent of the user Keychain.
- Verify current provider documentation before changes to login or model requests.
- Keep credentials out of source files, test data, logs, and shared Pharo images.
- Use the native credential store. Do not pass tokens through shell arguments.
- Treat image tools as full image access. Do not claim a sandbox or automatic rollback.

## Engineering principles

Use these ten principles from Dave Farley's *Modern Software Engineering*
to guide development and code review. The descriptions below apply the
principles to this project; they are not direct quotations.

### Improve learning

1. **Iteration.** Work in short cycles. Review each result and improve it in the next cycle.
2. **Feedback.** Get results early from tests, the running Pharo image, and the user. Use those results to guide the next change.
3. **Incrementalism.** Make small changes that can be checked independently. Keep the system working after each change.
4. **Empiricism.** Base decisions on observed behavior. Report what was tested and what remains unknown.
5. **Experimentation.** State the expected behavior before a change. Use a test or a small experiment to check it. For TDD, first observe the test fail, then make it pass, then refactor.

### Manage complexity

6. **Modularity.** Use small objects and modules with clear protocols. Make each part possible to understand and test separately.
7. **Cohesion.** Keep related state and behavior together. Give each object a clear purpose.
8. **Separation of concerns.** Keep the agent loop, provider connection, image tools, and user interface separate. Change each through its protocol.
9. **Information hiding and abstraction.** Expose the behavior callers need. Keep implementation details inside the object that owns them. Add abstractions for current requirements.
10. **Loose coupling.** Limit dependencies between objects and packages. Supply collaborators through simple protocols so that one implementation can change with little effect on others.

Source: [Modern Software Engineering — publisher's description and table of contents](https://www.informit.com/store/modern-software-engineering-doing-what-works-to-build-9780137314911).

## Language

Use ASD-STE100 Simplified Technical English for documentation, comments, and interface text.
Use English for class names, method names, and variable names.
Preserve Smalltalk conventions and exact external identifiers.

- Write short sentences with one topic.
- Use the active voice.
- Give one instruction in each procedural step.
- Use the same term for the same concept.
- Define new technical terms when necessary.
- Use approved words and meanings from the STE dictionary.
- Avoid idioms, unnecessary words, and promotional language.

Use the [official ASD-STE100 guidance](https://www.asd-ste100.org/STE_faq.html)
and the project terms in [README.md](README.md).

## Validation

Run tests that cover the changed behavior when a Pharo test environment is available.
Use a clean copied image for headless tests.
Use disposable classes and packages for image tool tests.
Keep live account checks and native Keychain checks separate from the offline suite.
Report the result and any limit on validation.
Update the documentation when the implemented behavior changes.
Do not describe a planned feature as available.

## Commits

- Use Conventional Commits with a required scope: `type(scope): description`.
- Keep each commit atomic. Include one logical change in each commit.
- Do not add `Co-authored-by` trailers or co-author attribution.
