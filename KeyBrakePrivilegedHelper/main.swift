import Foundation

let helperService = HelperService()
let semaphore = DispatchSemaphore(value: 0)
print("KeyBrakePrivilegedHelper ready: \(helperService.availability.rawValue)")
semaphore.wait()
