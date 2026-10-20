import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import App from "./App";

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("App", () => {
  it("shows the confirmed shared mailbox and does not pretend authentication is configured", () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ok: true,
          authenticationConfigured: false,
          mailboxRoutesEnabled: false,
        }),
      }),
    );

    render(<App />);

    expect(screen.getByText("info@bukanabriliantschools.com")).toBeInTheDocument();
    expect(screen.getByText("Google sign-in")).toBeInTheDocument();
    expect(screen.getByText("Email and password")).toBeInTheDocument();
    expect(screen.getByText("Sign-in is not enabled yet")).toBeInTheDocument();
  });
});
