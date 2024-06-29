import React, { useEffect, useState } from "react";
import { PrismLight as SyntaxHighlighter } from "react-syntax-highlighter";
import jsx from "react-syntax-highlighter/dist/esm/languages/prism/jsx";
import tsx from "react-syntax-highlighter/dist/esm/languages/prism/tsx";
import elixir from "react-syntax-highlighter/dist/esm/languages/prism/elixir";
import erb from "react-syntax-highlighter/dist/esm/languages/prism/erb";
import { darcula } from "react-syntax-highlighter/dist/esm/styles/prism";

SyntaxHighlighter.registerLanguage("jsx", jsx);
SyntaxHighlighter.registerLanguage("tsx", tsx);
SyntaxHighlighter.registerLanguage("elixir", elixir);
SyntaxHighlighter.registerLanguage("heex", erb);

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
        setCode(text);
      } catch (error) {
        console.error("Error fetching code:", error);
      }
    };

    fetchCode();
  }, []);

  return (
    <SyntaxHighlighter language={language} style={darcula} showLineNumbers>
      {code}
    </SyntaxHighlighter>
  );
}
