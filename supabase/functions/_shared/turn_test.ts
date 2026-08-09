import { filterBrowserIceUrls, utcMonthStart } from "./turn.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("TURN browser URL filter removes alternate port 53", () => {
  assertEquals(
    filterBrowserIceUrls([
      "stun:stun.cloudflare.com:3478",
      "stun:stun.cloudflare.com:53",
      "turn:turn.cloudflare.com:53?transport=udp",
      "turn:turn.cloudflare.com:3478?transport=udp",
      "turns:turn.cloudflare.com:443?transport=tcp",
      "https://example.com/not-an-ice-server",
    ]),
    [
      "stun:stun.cloudflare.com:3478",
      "turn:turn.cloudflare.com:3478?transport=udp",
      "turns:turn.cloudflare.com:443?transport=tcp",
    ],
  );
});

Deno.test("TURN usage periods start on the first day in UTC", () => {
  assertEquals(utcMonthStart(new Date("2026-08-31T23:59:59Z")), "2026-08-01");
  assertEquals(utcMonthStart(new Date("2026-09-01T00:00:00Z")), "2026-09-01");
});
