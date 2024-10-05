import React, { useEffect, useState } from "react";
import hljs from "highlight.js/lib/core";
import elixir from "highlight.js/lib/languages/elixir";
import erb from "highlight.js/lib/languages/erb";
import javascript from "highlight.js/lib/languages/javascript";
import typescript from "highlight.js/lib/languages/typescript";

import "highlight.js/styles/github.css";

hljs.registerLanguage("jsx", javascript);
hljs.registerLanguage("tsx", javascript);
hljs.registerLanguage("elixir", elixir);
hljs.registerLanguage("heex", erb);

export function GithubCode({ url, language }) {
  const [code, setCode] = useState("");

  useEffect(() => {
    const fetchCode = async () => {
      try {
        const response = await fetch(url);
        if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
        }
        let text = await response.text();
        text = text.trimEnd();
        const highlightedCode = hljs.highlight(text, { language }).value;
        setCode(highlightedCode);
      } catch (error) {
        console.error("Error fetching code:", error);
      }
    };

    fetchCode();
  }, []);

  return (
    <pre>
      <code dangerouslySetInnerHTML={{ __html: code }} />
    </pre>
  );
}
