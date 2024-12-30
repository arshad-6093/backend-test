
# **Backend Test**

This repository contains a backend server implemented in Haskell for the CentralApp backend technical test. The server proxies API requests, caches data with TTL, and supports environment-based configuration.

---

## **Features**

- **Proxy API**: Forward requests to the CentralApp `categories` endpoint.
- **Caching**: Caches responses in memory using STM for concurrent safety.
- **TTL Expiry**: Cache entries expire after a configurable time-to-live (TTL).
- **Periodic Cleanup**: Automatically removes expired cache entries.
- **Environment Configuration**: Configurable TTL, server port, and cleanup interval.

---

## **Requirements**

- **GHC**: Glasgow Haskell Compiler
- **Cabal**: Haskell build tool

---

## **Setup**

### **1. Clone the Repository**
```bash
git clone https://github.com/arshad-6093/backend-test.git
cd backend-test
```

### **2. Install Haskell Tools**
Follow the [Haskell installation guide](https://www.haskell.org/downloads/) to install `ghc` and `cabal`.

Verify installation:
```bash
ghc --version
cabal --version
```

### **3. Install Dependencies**
Inside the project directory:
```bash
cabal update
cabal build
```

---

## **Usage**

### **1. Configure Environment Variables**
Set optional environment variables to customize behavior:
```bash
export TTL_SECONDS=120        # Cache TTL in seconds (default: 60)
export SERVER_PORT=8080       # Server port (default: 8080)
export CACHE_CLEAN_INTERVAL=60 # Cache cleanup interval in seconds (default: 60)
```

### **2. Run the Server**
Start the server:
```bash
cabal run backend-test
```

The server will start on the specified port (default is `8080`).

### **3. Test the API**
Send a sample request using `curl` or a browser:
```bash
curl "http://localhost:8080/categories/like?name=italian&levels=L_1"
```

---

## **Endpoints**

| Method | Endpoint                                 | Description                                                      |
|--------|-----------------------------------------|------------------------------------------------------------------|
| GET    | `/categories/like?name={name}&levels={levels}` | Fetch categories matching the `name` and `levels` parameters. |

**Examples:**

1. **Default Endpoint**: Match by substring:
   ```bash
   curl "http://localhost:8080/categories/like?name=southern italian"
   ```

2. **Level 1 Categories**:
   ```bash
   curl "http://localhost:8080/categories/like?name=southern italian&levels=L_1"
   ```

3. **Level 0 and Level 1 Categories**:
   ```bash
   curl "http://localhost:8080/categories/like?name=restaurant&levels=L_0,L_1"
   ```

---

## **Environment Configuration**

| Variable               | Default Value | Description                                     |
|-------------------------|---------------|-------------------------------------------------|
| `TTL_SECONDS`          | `60`          | Time-to-live for cache entries (in seconds).   |
| `SERVER_PORT`          | `8080`        | Port where the server listens.                 |
| `CACHE_CLEAN_INTERVAL` | `60`          | Interval for periodic cache cleanup (seconds). |

---

## **Code Structure**

- **Main.hs**: Contains the entire server implementation, including:
  - **API Definition**: Defines the HTTP API using `Servant`.
  - **Cache Logic**: Manages caching with STM for concurrency.
  - **Proxy Requests**: Forwards API requests to CentralApp's categories endpoint.
  - **Configuration**: Fetches environment variables for customization.

---

## **How Caching Works**

1. **Caching Responses**:
   - When a request is made, the server checks if the response is already in the cache.
   - If cached and valid, it returns the cached response.
   - If not cached or expired, the server forwards the request to the external API and caches the response.

2. **Cache Expiry**:
   - Cache entries expire after the configured `TTL_SECONDS`.

3. **Cache Cleanup**:
   - A background thread periodically removes expired entries based on `CACHE_CLEAN_INTERVAL`.

---

## **Error Handling**

- Returns appropriate HTTP status codes:
  - **500 Internal Server Error**: For API or server errors.
  - **404 Not Found**: For no matching categories (optional behavior).

---

## **Testing**

### **Unit Testing Cache Logic**
- Test `lookupCache` and `updateCache` with mock data.
- Verify correct behavior for cache hits, misses, and TTL expiry.

### **Manual Testing**
1. Start the server:
   ```bash
   cabal run backend-test
   ```
2. Make API requests using `curl` or Postman.
3. Observe logs for cache hits, misses, and cleanup activity.

---

## **License**
This project is licensed under the BSD-3-Clause License.

---

## **Author**
**Mohammed Arshath**  
<arshad.kaleelrahman@gmail.com>

**+918098343268**