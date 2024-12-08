# 🚨Disclamer

This is a toy version of the lisp interpreter implemented by ***"fuck around and find out"*** with claude, 

discussing the approach and implementing it, 

I don't expect all the complex features to work nor the code to be optimal like a actual interpreter built by someone who knows this stuff, 

this was made for fun as a side project but I'll try to rewrite it when I am more knowledgable about this.

# Zisp - A Toy Lisp Interpreter in Zig

**Zisp** is a minimalistic Lisp interpreter crafted with **Zig**. 

This project was started because after reaching 58/109 exercises in ziglings, I got overwhelmed with the theory part,

https://github.com/user-attachments/assets/715597eb-6191-4e9e-8cfd-d34a74204bd3

But after beginning to lose interest I remembered that i was ***the*** top guy and cannot give up like this,

https://github.com/user-attachments/assets/2991d63b-8ce2-4a5b-adf8-4bf271792484

Having a low attention span and not having read ~10 pages of something in one sitting in past 8 years, im as good as a illiterate, 

educational videos too bore me.

So I decided to rawdog Claude with a series of "fuck around and find out" and started to build this, 

Since I'm getting results so I'll keep cooking

![cooking](https://github.com/user-attachments/assets/8597b557-3f2a-4918-b1c9-d550fed1e35a)


## Project Pipeline

```plaintext
Tokenizer -> Abstract Syntax Tree -> Parser -> Evaluator -> REPL Environment
   ✔️               ✔️                   ✔️           ✔️               ✔️ 
```
--- 
### 🚨**Zisp Highlights**
![zesty-sonic-zesty](https://github.com/user-attachments/assets/36448efb-f70e-4f56-a648-2d7dbf520a4e)

- **AST:** Hierarchical structure for Lisp expressions, with support for special forms.
- **Evaluator:** Implements key Lisp functions (`define`, `lambda`, `if`, etc.) with arithmetic and comparison operations.
- **Environment:** Manages variable scope with nested support.
- **REPL:** Interactive, multi-line capable, with immediate result display and simple exit commands.

### 🤫 POF(Proof of functionality)
![image](https://github.com/user-attachments/assets/1df4755c-0862-4d94-b709-333274dfc186)

```
zisp>(+ (* 2 3) (- 10 5))  
Result: -9

zisp>(define x 5)    
Result: 5

zisp>(define square (lambda (n) (* n n)))
Result: <lambda with 1 params>

zisp>(if (> 10 5) (* 2 3) (+ 1 1))
Result: 6

zisp>(begin (define y 10) (* y 2))  
Result: 20
```

### 🚧 Pending Features

<img width="756" alt="image" src="https://github.com/user-attachments/assets/44923880-99ca-4dcd-a655-1f6f853d14bc">


| Feature                | Description                                                                             | Status | Implementation Details                                                                 |
|------------------------|-----------------------------------------------------------------------------------------|--------|----------------------------------------------------------------------------------------|
| Strings                | Support for string literals in the Lisp code, allowing text manipulation                | ❌     | Not yet implemented                                                                    |
| Comments               | Support for semicolon-style comments, essential for code documentation                 | ❌     | Not yet implemented                                                                    |
| Float Numbers           | Support for decimal point numbers to enable non-integer arithmetic                     | ❌     | Not yet implemented                                                                    |
| Scientific Notation    | Support for exponential format numbers (e.g., 1e10) for very large or small values     | ❌     | Not yet implemented                                                                    |
| Error Reporting        | Line and column tracking for precise error location identification                      | ❌     | Not yet implemented                                                                    |
| Symbol Validation      | Enforcing symbol naming conventions in the Lisp code                                   | ✔️     | Implemented through tokenizer logic and AST node typing                                |
| Reserved Keywords      | Special handling of Lisp-specific keywords like `define`, `lambda`, `if`               | ✔️     | Fully implemented with special form handling in AST construction                       |
| Character Literals     | Support for single character values                                                     | ❌     | Not yet implemented                                                                    |
| Escape Sequences       | Support for special characters in strings and other literals                            | ❌     | Not yet implemented                                                                    |
| Alternative Bases      | Support for binary, octal, and hexadecimal number representations                       | ❌     | Not yet implemented                                                                    |
| Buffer Management      | Dynamic sizing of input buffers for handling varying input lengths                      | ❌     | Not yet implemented                                                                    |
| Error Recovery         | Graceful handling and recovery from malformed input                                     | ❌     | Not yet implemented                                                                    |

---


## 🏗️ Build and Run

<img width="472" alt="image" src="https://github.com/user-attachments/assets/09d9316f-c654-4ee3-bf2f-68f343b2763a">

To run Zisp, simply use:

```bash
zig build run
```
