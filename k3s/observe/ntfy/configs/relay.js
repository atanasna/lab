const http = require('node:http');

const ntfyServer = process.env.NTFY_SERVER;
const ntfyTopic = process.env.NTFY_TOPIC;

async function publish(alert, externalURL) {
  const labels = alert.labels ?? {};
  const annotations = alert.annotations ?? {};
  const status = alert.status ?? 'firing';
  const lines = [
    `Severity: ${labels.severity ?? 'unknown'}`,
    labels.instance && `Instance: ${labels.instance}`,
    annotations.summary,
    annotations.description,
    `Starts: ${alert.startsAt}`,
    status === 'resolved' && `Ends: ${alert.endsAt}`,
  ].filter(Boolean);
  const response = await fetch(`${ntfyServer}/${ntfyTopic}`, {
    method: 'POST',
    headers: {
      Title: `[${status}] ${labels.alertname ?? 'Alert'}`,
      Priority: status === 'firing' ? '5' : '2',
      Tags: status,
      ...(externalURL && { Click: externalURL }),
    },
    body: lines.join('\n\n'),
  });

  if (!response.ok) {
    throw new Error(`ntfy returned ${response.status}`);
  }
}

http.createServer(async (request, response) => {
  if (request.method !== 'POST' || request.url !== '/webhook') {
    response.writeHead(404).end();
    return;
  }

  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);

  try {
    const payload = JSON.parse(Buffer.concat(chunks).toString());
    await Promise.all((payload.alerts ?? []).map((alert) => publish(alert, payload.externalURL)));
    response.writeHead(200).end();
  } catch (error) {
    console.error(error);
    response.writeHead(500).end();
  }
}).listen(8080);
