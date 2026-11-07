# Upstream — telegram-ui-design (aliabedi1)

Source : https://github.com/aliabedi1/telegram-ui-design/blob/main/SKILL.md  
Licence / usage : fichier public GitHub ; recopié ici comme **référence** pour agents UpChat.

> Skill orienté **bots Telegram** (menus, keyboards, flux conversationnels), pas l'UI native client Telegram en Flutter.

---

```yaml
name: telegram-ui-design
description: Design or review Telegram bot conversation interfaces, menus, buttons, message layouts, and state flows using user needs and observed UI evidence.
```

# Telegram UI design

Use this skill when designing a Telegram bot's user-facing conversation flow or reviewing an existing one. Begin with the current product's users, tasks, data, and constraints. Treat other bots and screenshots as **references for interaction patterns**, never as requirements for the product being designed.

## Work from user needs to screens

1. Identify the user's jobs and the data or actions needed to complete them. Separate confirmed product requirements, observed reference behavior, your design recommendations, and unresolved decisions.
2. If reference bots, screenshots, or reports are supplied, map their visible states and transitions. For each control, record its label, keyboard type, destination, and whether it reads data, collects input, or changes state. Distinguish bot-controlled content from Telegram client chrome. Mark historical screens and untested branches.
3. Propose the smallest navigation structure that makes primary jobs easy to find. Group peer actions, keep a visible way back or home, and reveal detailed controls in context. Use pattern reference when choosing between reply keyboards, inline keyboards, message edits, and new messages.
4. Define each screen's content and behavior: entry trigger, data shown, text/media hierarchy, button rows, input validation, transition, and loading/empty/error/success states. State what happens when a user returns later or taps an old button.
5. Check the design in a narrow Telegram viewport, including long labels, mixed right-to-left and left-to-right text, expanded keyboards, and client banners. Make status clear in words as well as color or emoji.
6. When handing work to another agent, provide a flow map and button-to-state matrix with source evidence, data dependencies, open decisions, and testable acceptance criteria. When implementing, verify the resulting UI against that contract.

## Design bar

- A user can tell what the bot offers, what to do next, what has happened, and how to recover.
- Each visible button has one understandable effect and a defined destination.
- The interface is compact because information and actions are prioritized, while labels remain readable.
- User data is timely, attributed to a clear source, and presented only where it helps a decision.
- Actions with consequences have an appropriate review, confirmation, and truthful outcome.
- Reference patterns are adapted to the current product; no reference bot's content, pricing, or business rule becomes a requirement by accident.

This skill guides UI design. It does not authorize sending messages, purchasing, modifying accounts, or publishing content.

## Lien patterns

https://github.com/aliabedi1/telegram-ui-design/blob/main/references/patterns.md
