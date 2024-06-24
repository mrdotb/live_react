import React, { useEffect, useState } from "react";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { darcula } from "react-syntax-highlighter/dist/esm/styles/prism";

export function GithubCode({ url, language }) {
  const [code, setCode] = useState("");

  useEffect(() => {
    const fetchCode = async () => {
      try {
        const response = await fetch(url);
        if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
        }
        const text = await response.text();
        setCode(text);
      } catch (error) {
        console.error("Error fetching code:", error);
      }
    };

    fetchCode();
  }, []);

  return (
    <SyntaxHighlighter language={language} style={darcula}>
      {code}
    </SyntaxHighlighter>
  );
}
