import React from "react";
import { Box, Container, Typography, Paper } from "@mui/material";

export const App: React.FC = () => {
  return (
    <Box sx={{ minHeight: "100vh", bgcolor: "background.default", py: 4 }}>
      <Container maxWidth="lg">
        <Paper sx={{ p: 4, borderLeft: "6px solid", borderColor: "secondary.main" }}>
          <Typography variant="h4" fontWeight={700} color="primary.main" gutterBottom>
            Biblioteca Virtual de Ingeniería — Forjas Bolívar
          </Typography>
          <Typography variant="subtitle1" color="text.secondary">
            Fuente oficial de conocimiento técnico, normas (DIN, ISO, ASME, ASTM, SAE) y calculadoras parametrizadas.
          </Typography>
        </Paper>
      </Container>
    </Box>
  );
};

