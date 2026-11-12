const DEFAULT_FUNCTIONS_REGION = "asia-northeast3";
const LEGACY_FUNCTIONS_REGION = "us-central1";

function callableUrl({
  projectId,
  name,
  host = "127.0.0.1:5001",
  region = DEFAULT_FUNCTIONS_REGION,
}) {
  return `http://${host}/${projectId}/${region}/${name}`;
}

async function callCallable({
  projectId,
  name,
  idToken,
  data = {},
  region,
  host,
}) {
  const headers = {"content-type": "application/json"};
  if (idToken) headers.authorization = `Bearer ${idToken}`;
  const response = await fetch(callableUrl({projectId, name, region, host}), {
    method: "POST",
    headers,
    body: JSON.stringify({data}),
  });
  return {status: response.status, body: await response.json()};
}

module.exports = {
  DEFAULT_FUNCTIONS_REGION,
  LEGACY_FUNCTIONS_REGION,
  callableUrl,
  callCallable,
};
