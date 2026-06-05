// import http from "k6/http";

// export const options = {
//   vus: 100,
//   duration: "3m",
// };

// export default function () {
//   http.get("http://localhost:5001/health");
// }
import http from "k6/http";

export const options = {
  vus: 10,
  duration: "30s",
};

export default function () {
  http.get("http://localhost:5001/health");
}