# smart-overdose-detector
# Smart Overdose Detector  (Dispositivo Inteligente para Detección Temprana de Sobredosis)

![Status](https://img.shields.io/badge/Status-Development-orange)
![Architecture](https://img.shields.io/badge/Architecture-Hexagonal-blue)
![IA](https://img.shields.io/badge/IA-LSTM%20/%20TFLite-green)

##  Descripción del Proyecto
[cite_start]Este proyecto consiste en un sistema inteligente de monitoreo biométrico diseñado para la detección temprana de sobredosis por opioides y otras sustancias[cite: 1]. [cite_start]Utiliza una combinación de hardware **Wearable (Smartwatch)**, una **App Móvil** y un **Backend robusto** para identificar patrones fisiológicos críticos mediante Inteligencia Artificial [cite: 15-16, 51].

[cite_start]El problema central que abordamos es la detección tardía de eventos críticos y la ausencia de monitoreo continuo fuera del entorno hospitalario, lo que resulta en muertes evitables cuando la persona se encuentra sola [cite: 5-8, 11].

##  Impacto Social
El proyecto está diseñado con un enfoque regional para:
* Mejorar la continuidad terapéutica en la región **Junín**.
* Reducir costos de rehabilitación y apoyar a los hospitales de **Huancayo**.
* Facilitar la tele-rehabilitación rural en zonas de difícil acceso.

##  Stack Tecnológico
* [cite_start]**Frontend:** Flutter (Dart) para la plataforma móvil.
* [cite_start]**Backend:** FastAPI (Python) orientado a Arquitectura Hexagonal.
* [cite_start]**IA:** Modelos LSTM (Deep Learning) ejecutados en el móvil vía TensorFlow Lite.
* [cite_start]**Base de Datos:** PostgreSQL con extensión **TimescaleDB** para series temporales.
* [cite_start]**Hardware:** Smartwatch (Wear OS / WatchOS) para captura de señales (FC, $SpO_2$, Respiración).

##  Arquitectura de Software
[cite_start]El sistema implementa una **Arquitectura Hexagonal**, desacoplando el dominio clínico de los dispositivos y servicios externos para garantizar escalabilidad y testeabilidad [cite: 61-63, 121-122].

### Estructura del Repositorio
```text
src/
├── domain/                  # Núcleo del Negocio (Core)
[cite_start]│   ├── entities/            # Paciente, EventoRiesgo, SenalBiometrica
│   ├── valueobjects/        # BioMetria, CoordenadasGPS
[cite_start]│   └── services/            # Lógica de detección y reglas clínicas 
│
├── application/             # Casos de Uso
[cite_start]│   ├── usecases/            # MonitorizarSignos, DispararAlerta
│   └── ports/               # Interfaces de Entrada y Salida
│       ├── input/           # Puertos de Driver
│       └── output/          # Puertos de Driven
│
├── adapters/                # Implementaciones Técnicas
│   ├── in/                  # Adaptadores de Entrada
│   │   └── controllers/     # FastAPI Rest API / MQTT Handler
│   └── out/                 # Adaptadores de Salida
│       ├── persistence/     # TimescaleDB / PostgreSQL Adapter
[cite_start]│       ├── external/        # Twilio (SMS), Email Adapter 
[cite_start]│       └── ia_engine/       # Inferencia local con TFLite 
│
└── infrastructure/          # Configuración Global
    ├── configuration/       # Inyección de Dependencias
    └── poc/                 # << Proof of Concept >> Prototipos de Simulación IoT




