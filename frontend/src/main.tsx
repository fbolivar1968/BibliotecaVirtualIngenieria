import React from "react";
import ReactDOM from "react-dom/client";
import { CssBaseline, ThemeProvider, createTheme } from "@mui/material";
import { App } from "./app/App";

const fbTheme = createTheme({
  palette: {
    primary: {
      main: "#0B2545", // Azul corporativo Forjas Bolívar (según Mockup)
    },
    secondary: {
      main: "#F97316", // Naranja corporativo Forjas Bolívar (según Mockup)
    },
    background: {
      default: "#F4F6F9",
    },
  },
  typography: {
    fontFamily: "'Inter', 'Roboto', 'Segoe UI', sans-serif",
  },
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ThemeProvider theme={fbTheme}>
      <CssBaseline />
      <App />
    </ThemeProvider>
  </React.StrictMode>
);

