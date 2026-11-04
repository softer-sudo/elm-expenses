# elm-expenses

A small Elm 0.19 expense tracker that shows what purely functional code looks like in a real app. It loads expenses over HTTP. You can add, edit, delete and filter them, and it shows totals per category.

```sh
npm install
npm start        # builds and serves on http://localhost:8000
npm test         # elm-test: update function, decoders, pure helpers
```

## Layout

| File | What it holds |
|---|---|
| `src/Expense.elm` | Domain: the `Category` type, JSON decoders, amount parsing, totals. All pure. |
| `src/Main.elm` | The Elm Architecture: `Model`, `Msg`, `update`, `view`, plus the one HTTP command. |
| `tests/` | `ExpenseTest` covers the decoders and helpers. `MainTest` feeds messages to `update` and checks the model it returns. |
| `public/` | `index.html` and `expenses.json`, the "server" data. |

## Elm vs TypeScript + React

The same app in TypeScript + React would have a `useState`/`useReducer` store, `fetch` inside a `useEffect`, and a form component. The table below shows where the two differ.

### 1. Immutability

**Elm:** every value is immutable, and the language has no syntax for mutating anything. `{ model | filter = filter }` returns a new record.

**TS + React:** objects can be mutated by default. React *requires* you to replace state rather than change it in place, but nothing enforces that. `expenses.push(e); setExpenses(expenses)` compiles and then fails to re-render. `readonly` and `Readonly<T>` help, but they are opt-in and shallow.

### 2. Algebraic data types: impossible states are impossible

**Elm:**

```elm
type RemoteData e a = Loading | Failure e | Success a
type Mode = Adding | Editing Int
```

The list of expenses exists only inside `Success`. "Loaded but also has an error" cannot be written down. Neither can "editing, but which one?". `case` must handle every variant, or the code does not compile.

**TS + React:** the common version is

```ts
const [loading, setLoading] = useState(true);
const [error, setError] = useState<string | null>(null);
const [expenses, setExpenses] = useState<Expense[]>([]);
const [editingId, setEditingId] = useState<number | null>(null);
```

Those four fields allow 16 combinations, and most of them are nonsense. You *can* write a discriminated union (`{ status: "success"; data: Expense[] } | ...`) and a `never` check for exhaustiveness. That is the Elm design, but TS leaves it opt-in, and the libraries don't push you toward it.

### 3. Pure functions and managed effects

**Elm:** `update : Msg -> Model -> ( Model, Cmd Msg )` is a pure function. It never performs the HTTP request. It *returns* a description of it (`Http.get …`), and the runtime runs it and sends the result back as `GotExpenses (Result Http.Error (List Expense))`. That is why `MainTest` can test the whole app with no mocks, timers or DOM: it just folds messages over a model.

**TS + React:** effects run wherever you put them, usually in `useEffect`. Testing them means mocking `fetch` and rendering with a DOM library. A reducer can be pure, but only if everyone keeps it that way. Race conditions such as a stale response or an unmounted component are your problem.

### 4. Errors as values, no `null`

**Elm:** an absent value is a `Maybe`, and an operation that can fail returns a `Result`. `Expense.parseAmount : String -> Result String Int` lets a caller in only after handling `Err`. The JSON decoder rejects an unknown category or a fractional `amountCents` at the boundary, and the app shows a typed `Http.BadBody` message.

**TS + React:** `response.json()` returns `any`, and `as Expense[]` is a promise to the compiler that nobody checks. A bad payload goes on through the app until something reads `undefined.toFixed`. Getting Elm's guarantees means adding a runtime validator such as zod and remembering to use it on every input.

### 5. Type inference

**Elm:** Hindley–Milner inference means you could delete almost every annotation in this repo and it would still compile. `main` is the exception, because its flags type must be concrete. The rest are kept as documentation. Inference stays sound with no `any` escape hatch.

**TS + React:** inference is good inside a function, but boundaries need annotations (`useState<Expense[]>([])`, or `[]` is inferred as `never[]`). Callback parameters often need them too. `any` can leak in from libraries or JSON.

### 6. No runtime exceptions

**Elm:** with no `null`, no exceptions, exhaustive `case`, and decoders at every boundary, a compiled Elm app does not throw in practice. The remaining corners are rare things like stack overflow or `==` on functions. Here, failure is a variant of `RemoteData` that the view must render.

**TS + React:** `TypeError: Cannot read properties of undefined` is still the most common front-end crash. An error boundary keeps it from blanking the page, but it doesn't prevent the crash.

### What TS + React does better

It has a much bigger ecosystem, easy JS interop (Elm talks to JS only through ports), gradual adoption in an existing codebase, and far more developers who already know it. Elm trades flexibility for guarantees, which pays off most in apps that are heavy on state and forms, like this one.
