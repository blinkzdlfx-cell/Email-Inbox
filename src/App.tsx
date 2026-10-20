import { useEffect, useState } from "react";
import { LockKeyhole, Mail, ShieldCheck } from "lucide-react";

type HealthState = "checking" | "available" | "unavailable";

type HealthResponse = {
  ok?: boolean;
  authenticationConfigured?: boolean;
  mailboxRoutesEnabled?: boolean;
};

export default function App() {
  const [health, setHealth] = useState<HealthState>("checking");

  useEffect(() => {
    const controller = new AbortController();

    fetch("/api/health", { signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error("Health check failed");
        return (await response.json()) as HealthResponse;
      })
      .then((data) => setHealth(data.ok ? "available" : "unavailable"))
      .catch((error: unknown) => {
        if (error instanceof Error && error.name === "AbortError") return;
        setHealth("unavailable");
      });

    return () => controller.abort();
  }, []);

  return (
    <main className="min-h-screen bg-slate-50 px-4 py-10 text-ink sm:px-6">
      <div className="mx-auto flex min-h-[calc(100vh-5rem)] w-full max-w-5xl flex-col">
        <header className="flex items-center gap-3">
          <div className="grid h-11 w-11 place-items-center rounded-2xl bg-brand text-white shadow-sm">
            <Mail aria-hidden="true" size={22} />
          </div>
          <div>
            <p className="text-base font-semibold tracking-tight">Bukana</p>
            <p className="text-sm text-muted">School Email Inbox</p>
          </div>
        </header>

        <section className="grid flex-1 items-center gap-12 py-12 md:grid-cols-[1.05fr_0.95fr] md:py-16">
          <div className="max-w-xl">
            <div className="mb-5 inline-flex items-center gap-2 rounded-full border border-emerald-100 bg-white px-3 py-1.5 text-xs font-medium text-brand">
              <ShieldCheck size={15} aria-hidden="true" />
              Staff-only workspace
            </div>
            <h1 className="text-4xl font-semibold leading-tight tracking-tight sm:text-5xl">
              School communication, in one secure place.
            </h1>
            <p className="mt-5 max-w-lg text-base leading-7 text-muted sm:text-lg">
              Access to the shared school inbox will be available to approved staff after secure sign-in and mailbox permissions are configured.
            </p>
            <div className="mt-8 flex items-start gap-3 rounded-xl border border-slate-200 bg-white p-4">
              <LockKeyhole className="mt-0.5 shrink-0 text-brand" size={19} aria-hidden="true" />
              <div>
                <p className="text-sm font-semibold">Sign-in is not enabled yet</p>
                <p className="mt-1 text-sm leading-6 text-muted">
                  Authentication is intentionally unavailable until the identity provider, school staff approval, and production settings are configured. No mailbox data is exposed by this foundation build.
                </p>
              </div>
            </div>
          </div>

          <aside className="rounded-3xl border border-slate-200 bg-white p-6 shadow-panel sm:p-8">
            <p className="text-sm font-semibold text-muted">Shared school mailbox</p>
            <p className="mt-2 break-words text-xl font-semibold tracking-tight sm:text-2xl">
              info@bukanabriliantschools.com
            </p>
            <div className="my-6 h-px bg-slate-100" />
            <p className="text-sm font-medium">Planned sign-in methods</p>
            <div className="mt-3 space-y-3">
              <div className="flex items-center justify-between rounded-xl border border-slate-200 px-4 py-3">
                <span className="text-sm font-medium">Google sign-in</span>
                <span className="rounded-full bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-800">Setup pending</span>
              </div>
              <div className="flex items-center justify-between rounded-xl border border-slate-200 px-4 py-3">
                <span className="text-sm font-medium">Email and password</span>
                <span className="rounded-full bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-800">Setup pending</span>
              </div>
            </div>
            <div className="mt-6 flex items-center justify-between border-t border-slate-100 pt-4 text-xs text-muted">
              <span>API foundation</span>
              <span className="inline-flex items-center gap-2">
                <span className={health === "available" ? "h-2 w-2 rounded-full bg-emerald-500" : health === "unavailable" ? "h-2 w-2 rounded-full bg-rose-500" : "h-2 w-2 rounded-full bg-amber-400"} />
                {health === "available" ? "Responding" : health === "unavailable" ? "Unavailable" : "Checking"}
              </span>
            </div>
          </aside>
        </section>

        <footer className="border-t border-slate-200 py-5 text-xs text-muted">
          Bukana Brilliant Schools · Access is restricted to authorized staff.
        </footer>
      </div>
    </main>
  );
}
