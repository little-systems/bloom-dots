// Audit-only: one DeviceArt drawing for recording.
import ReactDOM from "react-dom/client";
import { DeviceArt, DeviceArtDefs } from "./devices/DeviceArt";

const q = new URLSearchParams(location.search);
ReactDOM.createRoot(document.getElementById("root")!).render(
	<>
		<DeviceArtDefs />
		<DeviceArt art={q.get("art") as any} phase={(q.get("phase") as any) || "play"} runId={0} size={60} />
	</>
);
