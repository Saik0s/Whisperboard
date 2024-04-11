//
// Target+Templates.swift
// GetLost
//

import ProjectDescription

public let deploymentTargetString = "16.0"
public let appDeploymentTargets: DeploymentTargets = .iOS(deploymentTargetString)
public let appDestinations: Destinations = [.iPhone, .iPad]

public let version = "1.11.9"
