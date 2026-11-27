// 2024 Adult Compendium, DOI 10.1016/j.jshs.2023.10.010.
// Positive speeds map continuously to the nearest published speed band
// (monotonic, zero float-equality traps, zero unmapped gaps).
export function compendiumDistanceMet(activityType: string, speedKmh: number) {
  const mph = Number.isFinite(speedKmh) && speedKmh > 0
    ? speedKmh / 1.609344
    : 0;
  switch (activityType.toLowerCase()) {
    case "walking":
      if (mph <= 0) return { code: "17255", met: 4.0 }; // Self-selected walking
      if (mph < 2.0) return { code: "17151", met: 2.3 };
      if (mph < 2.45) return { code: "17152", met: 2.8 };
      if (mph < 2.65) return { code: "17170", met: 3.0 };
      if (mph < 3.45) return { code: "17190", met: 3.8 };
      if (mph < 3.95) return { code: "17200", met: 4.8 };
      if (mph < 4.45) return { code: "17220", met: 5.5 };
      if (mph < 4.95) return { code: "17230", met: 7.0 };
      return { code: "17231", met: 8.5 };
    case "running":
      if (mph <= 0) return { code: "12145", met: 10.5 }; // Self-selected running
      if (mph < 4.25) return { code: "12028", met: 6.5 };
      if (mph < 4.9) return { code: "12029", met: 7.8 };
      if (mph < 5.35) return { code: "12030", met: 8.5 };
      if (mph < 5.9) return { code: "12045", met: 9.0 };
      if (mph < 6.5) return { code: "12050", met: 9.3 };
      if (mph < 6.85) return { code: "12060", met: 10.5 };
      if (mph < 7.25) return { code: "12070", met: 11.0 };
      if (mph < 7.75) return { code: "12080", met: 11.8 };
      if (mph < 8.3) return { code: "12090", met: 12.0 };
      if (mph < 8.8) return { code: "12100", met: 12.5 };
      if (mph < 9.15) return { code: "12110", met: 13.0 };
      if (mph < 9.8) return { code: "12115", met: 14.8 };
      if (mph < 10.5) return { code: "12120", met: 14.8 };
      if (mph < 11.5) return { code: "12130", met: 16.8 };
      if (mph < 12.5) return { code: "12132", met: 18.5 };
      if (mph < 13.5) return { code: "12134", met: 19.8 };
      return { code: "12135", met: 23.0 };
    case "cycling":
      if (mph <= 0) return { code: "01014", met: 7.0 }; // General bicycling
      if (mph < 10.0) return { code: "01010", met: 4.0 };
      if (mph < 12.0) return { code: "01020", met: 6.8 };
      if (mph < 14.0) return { code: "01030", met: 8.0 };
      if (mph < 16.0) return { code: "01040", met: 10.0 };
      if (mph <= 20.0) return { code: "01050", met: 12.0 };
      // 01060 explicitly assumes racing without drafting; the app cannot
      // verify drafting. The published >20 mph intensity is an estimate.
      return { code: "01060", met: 16.8 };
    default:
      return null;
  }
}
