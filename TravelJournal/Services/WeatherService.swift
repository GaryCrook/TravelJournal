import Foundation
import SwiftData

// WeatherService
//
// Fetches historical weather for each Visit in a trip using the Open-Meteo
// archive API (https://open-meteo.com). No API key required.
//
// Data stored in Visit.weather as a human-readable summary string, e.g.:
//   "Partly cloudy, 14–22°C, 1.2mm rain"
//
// Safe to re-run: skips visits where weather is already set.
// Runs after GPSClusteringService (needs location coordinates).

@Observable
class WeatherService {

    var isRunning = false
    var status = ""

    // MARK: - Public entry point

    @MainActor
    func fetchWeather(for trip: Trip, context: ModelContext) async {
        guard !isRunning else { return }

        let calendar = Calendar.current

        // Group visits by (location identifier, calendar day) so we fetch once
        // per unique place+date and apply the result to all matching visits.
        struct Key: Hashable {
            let locationId: ObjectIdentifier
            let day: Date
        }

        var groups: [Key: (location: Location, visits: [Visit])] = [:]
        for visit in trip.visits {
            guard let loc = visit.location, visit.weather.isEmpty else { continue }
            let key = Key(locationId: ObjectIdentifier(loc),
                          day: calendar.startOfDay(for: visit.datetime))
            if groups[key] != nil {
                groups[key]!.visits.append(visit)
            } else {
                groups[key] = (loc, [visit])
            }
        }

        guard !groups.isEmpty else {
            status = "Weather already fetched."
            return
        }

        isRunning = true
        let keys = groups.keys.sorted { $0.day < $1.day }
        let total = keys.count

        for (index, key) in keys.enumerated() {
            guard let group = groups[key] else { continue }
            status = "Fetching weather \(index + 1) of \(total)…"

            if let summary = await fetch(latitude: group.location.latitude,
                                         longitude: group.location.longitude,
                                         date: key.day) {
                for visit in group.visits { visit.weather = summary }
            }

            if index < total - 1 {
                try? await Task.sleep(for: .milliseconds(300))
            }
        }

        try? context.save()
        let fetched = trip.visits.filter { !$0.weather.isEmpty }.count
        status = "Weather fetched for \(fetched) visit\(fetched == 1 ? "" : "s")."
        isRunning = false
    }

    // MARK: - Network

    private func fetch(latitude: Double, longitude: Double, date: Date) async -> String? {
        let dateStr = isoDate(from: date)
        var components = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
        components.queryItems = [
            .init(name: "latitude",  value: String(format: "%.6f", latitude)),
            .init(name: "longitude", value: String(format: "%.6f", longitude)),
            .init(name: "start_date", value: dateStr),
            .init(name: "end_date",   value: dateStr),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum,weathercode"),
            .init(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parse(data)
        } catch {
            return nil
        }
    }

    // MARK: - Parse

    private func parse(_ data: Data) -> String? {
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let daily   = json["daily"] as? [String: Any],
            let maxArr  = daily["temperature_2m_max"] as? [Any],
            let minArr  = daily["temperature_2m_min"] as? [Any],
            let precipArr = daily["precipitation_sum"] as? [Any],
            let codeArr = daily["weathercode"] as? [Any],
            let maxTemp = (maxArr.first as? Double),
            let minTemp = (minArr.first as? Double),
            let code    = (codeArr.first as? Double).map({ Int($0) })
               ?? (codeArr.first as? Int)
        else { return nil }

        let condition = description(for: code)
        var parts = [condition, "\(Int(minTemp.rounded()))–\(Int(maxTemp.rounded()))°C"]

        if let precip = precipArr.first as? Double, precip >= 0.5 {
            parts.append(String(format: "%.1fmm rain", precip))
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - WMO weather code → description

    private func description(for code: Int) -> String {
        switch code {
        case 0:       return "Clear sky"
        case 1:       return "Mainly clear"
        case 2:       return "Partly cloudy"
        case 3:       return "Overcast"
        case 45, 48:  return "Foggy"
        case 51, 53:  return "Light drizzle"
        case 55:      return "Heavy drizzle"
        case 61:      return "Light rain"
        case 63:      return "Moderate rain"
        case 65:      return "Heavy rain"
        case 71:      return "Light snow"
        case 73:      return "Moderate snow"
        case 75:      return "Heavy snow"
        case 77:      return "Snow grains"
        case 80:      return "Light showers"
        case 81:      return "Moderate showers"
        case 82:      return "Heavy showers"
        case 85, 86:  return "Snow showers"
        case 95:      return "Thunderstorm"
        case 96, 99:  return "Thunderstorm with hail"
        default:      return "Variable"
        }
    }

    // MARK: - Helpers

    private func isoDate(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
