from pydantic import BaseModel, Field, validator
from typing import List, Optional, Dict, Any, Literal
from datetime import datetime
import uuid

class ExpectationTarget(BaseModel):
    targetName: str
    targetValue: Any
    targetUnit: Optional[str] = None
    targetOperator: Optional[str] = "="

class IntentExpectation(BaseModel):
    expectationId: str = Field(default_factory=lambda: str(uuid.uuid4()))
    expectationName: str
    expectationType: Literal["PERFORMANCE", "CAPACITY", "COVERAGE", "AVAILABILITY", "LATENCY", "THROUGHPUT"]
    expectationTargets: List[ExpectationTarget]
    priority: Optional[int] = Field(default=5, ge=1, le=10)

class IntentMetadata(BaseModel):
    createdAt: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    createdBy: Optional[str] = "LLM-Adapter"
    version: str = "1.0"
    source: str = "Natural Language Processing"
    additionalInfo: Optional[Dict[str, Any]] = None

class TMF921Intent(BaseModel):
    intentId: str = Field(default_factory=lambda: str(uuid.uuid4()))
    intentName: str
    intentDescription: Optional[str] = None
    intentType: Literal["SERVICE_INTENT", "RESOURCE_INTENT", "NETWORK_SLICE_INTENT"]
    intentState: Literal["CREATED", "VALIDATED", "DEPLOYED", "ACTIVE", "SUSPENDED", "TERMINATED"] = "CREATED"
    intentPriority: int = Field(default=5, ge=1, le=10)
    targetSite: Literal["edge1", "edge2", "both"] = "edge1"
    intentExpectations: List[IntentExpectation]
    intentMetadata: IntentMetadata = Field(default_factory=IntentMetadata)
    
    @validator('intentExpectations')
    def validate_expectations(cls, v):
        if not v:
            raise ValueError("At least one expectation is required")
        return v

def validate_tmf921_intent(intent_dict: Dict[str, Any]) -> TMF921Intent:
    """Validate and normalize an intent dictionary to TMF921 schema."""
    try:
        return TMF921Intent(**intent_dict)
    except Exception as e:
        raise ValueError(f"Intent validation failed: {str(e)}")

def create_example_intent() -> Dict[str, Any]:
    """Create an example TMF921-compliant intent."""
    return {
        "intentId": str(uuid.uuid4()),
        "intentName": "5G Gaming Slice Intent",
        "intentDescription": "Deploy a 5G network slice optimized for gaming services",
        "intentType": "NETWORK_SLICE_INTENT",
        "intentState": "CREATED",
        "intentPriority": 8,
        "targetSite": "edge2",
        "intentExpectations": [
            {
                "expectationId": str(uuid.uuid4()),
                "expectationName": "Ultra-Low Latency",
                "expectationType": "LATENCY",
                "expectationTargets": [
                    {
                        "targetName": "end-to-end-latency",
                        "targetValue": 10,
                        "targetUnit": "ms",
                        "targetOperator": "<="
                    }
                ],
                "priority": 9
            },
            {
                "expectationId": str(uuid.uuid4()),
                "expectationName": "High Throughput",
                "expectationType": "THROUGHPUT",
                "expectationTargets": [
                    {
                        "targetName": "download-speed",
                        "targetValue": 1000,
                        "targetUnit": "Mbps",
                        "targetOperator": ">="
                    },
                    {
                        "targetName": "upload-speed",
                        "targetValue": 100,
                        "targetUnit": "Mbps",
                        "targetOperator": ">="
                    }
                ],
                "priority": 7
            },
            {
                "expectationId": str(uuid.uuid4()),
                "expectationName": "Service Availability",
                "expectationType": "AVAILABILITY",
                "expectationTargets": [
                    {
                        "targetName": "service-availability",
                        "targetValue": 99.99,
                        "targetUnit": "%",
                        "targetOperator": ">="
                    }
                ],
                "priority": 8
            }
        ],
        "intentMetadata": {
            "createdAt": datetime.utcnow().isoformat(),
            "createdBy": "LLM-Adapter",
            "version": "1.0",
            "source": "Natural Language Processing",
            "additionalInfo": {
                "region": "urban",
                "serviceType": "gaming"
            }
        }
    }