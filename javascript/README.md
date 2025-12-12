# JavaScript/TypeScript Voice Assistant Samples

[Reference documentation](https://learn.microsoft.com/javascript/api/overview/azure/ai-voicelive-readme) | [Package (npm)](https://www.npmjs.com/package/@azure/ai-voicelive)

This folder contains JavaScript samples demonstrating how to build real-time voice assistants using Azure AI Speech VoiceLive service. Each sample is self-contained for easy understanding and deployment.

## Available Samples

### [Basic Web Voice Assistant](./basic-web-voice-assistant/)

A browser-based voice assistant demonstrating Azure Voice Live SDK integration in a web application using TypeScript and the Web Audio API.

**Key Features:**
- Client/Session architecture with type-safe handler-based events
- Real-time bi-directional audio streaming (PCM16)
- Live transcription and streaming text responses
- Barge-in support for natural conversation interruption
- Audio level visualization
- Support for OpenAI and Azure Neural voices

## Prerequisites

All samples require:

- [Node.js 18+](https://nodejs.org/) with npm
- Modern browser (Chrome 66+, Firefox 60+, Safari 11.1+, Edge 79+)
- [Azure subscription](https://azure.microsoft.com/free/) - Create one for free
- [AI Foundry resource](https://learn.microsoft.com/azure/ai-services/multi-service-resource) with Voice Live enabled

## Getting Started

See individual sample READMEs for detailed setup instructions.

## Resources

- [Azure AI Speech - Voice Live Documentation](https://learn.microsoft.com/azure/ai-services/speech-service/voice-live)
- [Support Guide](../SUPPORT.md)

## See Also

- [C# Samples](../csharp/README.md) - .NET implementation
- [Python Samples](../python/README.md) - Python implementation
- [Java Samples](../java/README.md) - Java implementation
