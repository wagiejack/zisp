# Zisp - A Toy Lisp Interpreter in Zig

**Zisp** is a minimalistic Lisp interpreter crafted with **Zig**. 

This project was started because after reaching 58/109 exercises in ziglings, I got overwhelmed with the theory part,

https://github.com/user-attachments/assets/715597eb-6191-4e9e-8cfd-d34a74204bd3

But after beginning to lose interest I remembered that i was the top guy and cannot give up like this,

https://github.com/user-attachments/assets/2991d63b-8ce2-4a5b-adf8-4bf271792484

I have very low attention span and im as goog as a illiterate, educational videos too bore me.

So I decided to rawdog Claude with a series of "f around and find out" and started to build this, I think I'm getting results so I'll keep cooking

![cooking](https://github.com/user-attachments/assets/8597b557-3f2a-4918-b1c9-d550fed1e35a)


## Project Pipeline

```plaintext
Tokenizer -> Abstract Syntax Tree -> Parser -> Evaluator -> REPL Environment
   ✔️              ❌                   ❌         ❌              ❌
```
---
## 🚀 Tokenizer

- **Features:**
  
![zesty-sonic-zesty](https://github.com/user-attachments/assets/36448efb-f70e-4f56-a648-2d7dbf520a4e)

  
  - **REPL Interface:** Interactive Lisp environment.
  - **Token Classification:** Recognizes parentheses, symbols, and numbers.
  - **Multi-line Input:** Handles inputs spanning multiple lines.
  - **Basic Operations:** Supports simple integer arithmetic.
  - **Memory Management:** Uses both Arena and General Purpose Allocator.

### 🚧 Pending Features

<img width="756" alt="image" src="https://github.com/user-attachments/assets/44923880-99ca-4dcd-a655-1f6f853d14bc">


| Feature                | Description                         | Status  |
|------------------------|-------------------------------------|---------|
| **Strings**            | Support for string literals         | ❌      |
| **Comments**           | Semicolon-style comments            | ❌      |
| **Float Numbers**      | Decimal point numbers               | ❌      |
| **Scientific Notation**| Exponential format (e.g., `1e10`)   | ❌      |
| **Error Reporting**    | Line/column tracking for errors     | ❌      |
| **Symbol Validation**  | Enforcing symbol naming conventions | ❌      |
| **Reserved Keywords**  | Handling Lisp-specific keywords     | ❌      |
| **Character Literals** | Single character support            | ❌      |
| **Escape Sequences**   | Support for special characters      | ❌      |
| **Alternative Bases**  | Binary, octal, hexadecimal numbers  | ❌      |
| **Buffer Management**  | Dynamic buffer sizing for input     | ❌      |
| **Error Recovery**     | Graceful handling of malformed input| ❌      |

---

## 🏗️ Build and Run

<img width="472" alt="image" src="https://github.com/user-attachments/assets/09d9316f-c654-4ee3-bf2f-68f343b2763a">

To run Zisp, simply use:

```bash
zig build run
```
