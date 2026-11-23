// 2024 Adult Compendium, DOI 10.1016/j.jshs.2023.10.010.
export function compendiumDistanceMet(activityType: string, speedKmh: number) {
  const mph = Number.isFinite(speedKmh) && speedKmh > 0
    ? speedKmh / 1.609344
    : 0;
  switch (activityType.toLowerCase()) {
    case "walking":
      if (mph > 0 && mph < 2.0) return { code: "17151", met: 2.3 };
      if (mph >= 2.0 && mph <= 2.4) return { code: "17152", met: 2.8 };
      if (mph === 2.5) return { code: "17170", met: 3.0 };
      if (mph >= 2.8 && mph <= 3.4) return { code: "17190", met: 3.8 };
      if (mph >= 3.5 && mph <= 3.9) return { code: "17200", met: 4.8 };
      if (mph >= 4.0 && mph <= 4.4) return { code: "17220", met: 5.5 };
      if (mph >= 4.5 && mph <= 4.9) return { code: "17230", met: 7.0 };
      if (mph >= 5.0 && mph <= 5.5) return { code: "17231", met: 8.5 };
      return { code: "17255", met: 4.0 }; // Self-selected walking
    case "running":
      if (mph >= 4.0 && mph <= 4.2) return { code: "12028", met: 6.5 };
      if (mph >= 4.3 && mph <= 4.8) return { code: "12029", met: 7.8 };
      if (mph >= 5.0 && mph <= 5.2) return { code: "12030", met: 8.5 };
      if (mph >= 5.5 && mph <= 5.8) return { code: "12045", met: 9.0 };
      if (mph >= 6.0 && mph <= 6.3) return { code: "12050", met: 9.3 };
      if (mph === 6.7) return { code: "12060", met: 10.5 };
      if (mph === 7.0) return { code: "12070", met: 11.0 };
      if (mph === 7.5) return { code: "12080", met: 11.8 };
      if (mph === 8.0) return { code: "12090", met: 12.0 };
      if (mph === 8.6) return { code: "12100", met: 12.5 };
      if (mph === 9.0) return { code: "12110", met: 13.0 };
      if (mph >= 9.3 && mph <= 9.6) return { code: "12115", met: 14.8 };
      if (mph === 10.0) return { code: "12120", met: 14.8 };
      if (mph === 11.0) return { code: "12130", met: 16.8 };
      if (mph === 12.0) return { code: "12132", met: 18.5 };
      if (mph === 13.0) return { code: "12134", met: 19.8 };
      if (mph === 14.0) return { code: "12135", met: 23.0 };
      return { code: "12145", met: 10.5 }; // Self-selected running
    case "cycling":
      if (mph > 0 && mph < 10.0) return { code: "01010", met: 4.0 };
      if (mph >= 10.0 && mph <= 11.9) return { code: "01020", met: 6.8 };
      if (mph >= 12.0 && mph <= 13.9) return { code: "01030", met: 8.0 };
      if (mph >= 14.0 && mph <= 15.9) return { code: "01040", met: 10.0 };
      if (mph >= 16.0 && mph <= 19.0) return { code: "01050", met: 12.0 };
      // 01060 explicitly assumes racing without drafting; the app cannot
      // verify drafting. The published >20 mph intensity is an estimate.
      if (mph > 20.0) return { code: "01060", met: 16.8 };
      return { code: "01014", met: 7.0 }; // General bicycling
    default:
      return null;
  }
}
