# Backend Configuration Guide

## Overview

The iOS Weather Dashboard app relies on a backend proxy server to securely communicate with weather APIs. This guide explains how to set up and configure the backend server for production use.

## Server Requirements

- Node.js 16+ and npm installed
- Express.js knowledge (for customizations)
- Internet connection for API communication
- Optional: SSL certificate for HTTPS

## Installation

### Clone the Backend Repository

```bash
git clone https://github.com/needsupport/react-weather-dashboard.git
cd react-weather-dashboard/server
```

### Install Dependencies

```bash
npm install
```

### Configuration Options

Create a `.env` file in the server directory with the following settings:

```env
# Port for the server to listen on
PORT=3001

# Default weather API type (nws or openweather)
WEATHER_API_TYPE=nws

# Default weather API URL
WEATHER_API_URL=https://api.weather.gov

# OpenWeather API key (optional if using NWS)
OPENWEATHER_API_KEY=your_api_key_here

# Cache duration in minutes
CACHE_DURATION=10

# Rate limit window in milliseconds (15 minutes)
RATE_LIMIT_WINDOW_MS=900000

# Maximum requests per rate limit window
RATE_LIMIT_MAX_REQUESTS=50
```

## Running the Server

### Development Mode

```bash
npm run dev
```

### Production Mode

```bash
npm start
```

## Configuring the iOS App

In the iOS app, update the `baseURL` in `WeatherAPIService.swift` to point to your backend server:

```swift
private let baseURL = "https://your-server-url.com/api" // Replace with your deployment URL
```

## API Endpoints

The backend server provides the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/config` | GET | Get current server configuration |
| `/api/config` | POST | Update server configuration |
| `/api/weather/points` | GET | Get grid points for coordinates |
| `/api/weather/forecast` | GET | Get forecast using endpoint from points response |
| `/api/weather/stations` | GET | Get weather stations |
| `/api/weather/observations` | GET | Get station observations |
| `/api/weather/alerts` | GET | Get active weather alerts |
| `/api/weather/gridpoints` | GET | Get detailed forecast data |
| `/api/weather` | GET | Legacy endpoint for OpenWeather API |
| `/health` | GET | Health check endpoint |

## Security Considerations

### API Key Protection

The OpenWeather API key is stored on the server and never exposed to clients. All API requests are proxied through the backend server.

### Rate Limiting

The server implements rate limiting to prevent abuse and stay within API provider limits. Configure the rate limit settings in the `.env` file.

### CORS Configuration

By default, CORS is enabled for all origins during development. For production, you should restrict this to your app's domain.

Modify the CORS configuration in `index.js`:

```javascript
// For production
app.use(cors({
  origin: 'https://your-app-domain.com'
}));
```

## Scaling Considerations

### Caching Strategy

The server uses `apicache` middleware for caching API responses. The default cache duration is 10 minutes, which you can modify in the `.env` file.

For production with multiple server instances, consider using a shared cache like Redis:

```javascript
const redis = require('redis');
const client = redis.createClient();
const cache = apicache.options({ redisClient: client }).middleware;
```

### Load Balancing

For high-traffic applications, deploy multiple instances of the server behind a load balancer such as Nginx or AWS ELB.

## Deployment Options

### Self-Hosted

- Deploy on a VPS like DigitalOcean, Linode, or AWS EC2
- Use PM2 for process management
- Set up Nginx as a reverse proxy

### Serverless

- AWS Lambda with API Gateway
- Vercel Serverless Functions
- Netlify Functions

### Containerized

- Docker container deployment
- Kubernetes for orchestration

## Monitoring and Maintenance

### Health Checks

The server provides a `/health` endpoint that returns the current status and configuration.

### Logging

Implement a logging solution for production:

```javascript
const winston = require('winston');
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});
```

### Error Handling

Implement global error handling for unhandled exceptions:

```javascript
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  // Graceful shutdown
  process.exit(1);
});
```

## Troubleshooting

### Common Issues

1. **Network Errors**: Ensure the server has internet access to reach the weather APIs.

2. **API Rate Limiting**: If you see 429 errors, adjust the rate limiting settings.

3. **Memory Leaks**: For long-running servers, monitor memory usage and implement proper cleanup.

### Debugging

Enable debug logs by setting the environment variable:

```bash
DEBUG=express:* npm start
```

## Support and Resources

- [National Weather Service API Documentation](https://www.weather.gov/documentation/services-web-api)
- [OpenWeather API Documentation](https://openweathermap.org/api)
- [Express.js Documentation](https://expressjs.com/)
- [Node.js Documentation](https://nodejs.org/en/docs/)