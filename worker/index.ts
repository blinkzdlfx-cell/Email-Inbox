type Env = {
  ASSETS: {
    fetch(request: Request): Promise<Response>;
  };
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/health") {
      if (request.method !== "GET") {
        return json({ error: "method_not_allowed" }, 405);
      }

      return json({
        ok: true,
        service: "bukana-email-inbox-api",
        stage: "foundation",
        authenticationConfigured: false,
        mailboxRoutesEnabled: false,
      });
    }

    if (url.pathname.startsWith("/api/")) {
      return json({ error: "not_found" }, 404);
    }

    return env.ASSETS.fetch(request);
  },
};
