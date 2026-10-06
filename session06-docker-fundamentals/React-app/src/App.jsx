import { useState } from "react";

export default function App() {
  const [count, setCount] = useState(0);
  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
      <h1>Hello World from React in Docker!</h1>
      <p>Session 06 - Poorav Kumar Gupta (24bcs10080)</p>
      <button onClick={() => setCount(count + 1)}>Clicked {count} times</button>
    </main>
  );
}
