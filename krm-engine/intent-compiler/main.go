package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	"sigs.k8s.io/kustomize/kyaml/fn/framework"
	"sigs.k8s.io/kustomize/kyaml/yaml"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	appsv1 "k8s.io/api/apps/v1"
)

type Intent struct {
	IntentID      string         `json:"intentId"`
	IntentType    string         `json:"intentType"`
	TargetSites   []string       `json:"targetSites"`
	ServiceProfile ServiceProfile `json:"serviceProfile"`
}

type ServiceProfile struct {
	Bandwidth     string `json:"bandwidth,omitempty"`
	Latency       string `json:"latency,omitempty"`
	Reliability   string `json:"reliability,omitempty"`
	DeviceDensity string `json:"deviceDensity,omitempty"`
}

func main() {
	processor := framework.SimpleProcessor{
		Config: &Intent{},
		Filter: framework.ResourceMatchers{
			&framework.ResourceMatcher{
				Kinds: []string{"Intent"},
			},
		},
		Run: processIntent,
	}

	if err := framework.Execute(processor, &framework.ExecuteConfig{
		Network: false,
	}); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func processIntent(rl *framework.ResourceList) error {
	for i := range rl.Items {
		resource := &rl.Items[i]

		// Parse Intent resource
		intentData := resource.Field("spec")
		if intentData == nil {
			continue
		}

		intentJSON, err := intentData.MarshalJSON()
		if err != nil {
			return fmt.Errorf("failed to marshal intent spec: %v", err)
		}

		var intent Intent
		if err := json.Unmarshal(intentJSON, &intent); err != nil {
			return fmt.Errorf("failed to unmarshal intent: %v", err)
		}

		// Generate KRM resources based on intent type
		switch intent.IntentType {
		case "eMBB":
			if err := generateEMBBResources(rl, &intent); err != nil {
				return err
			}
		case "URLLC":
			if err := generateURLLCResources(rl, &intent); err != nil {
				return err
			}
		case "mMTC":
			if err := generateMMTCResources(rl, &intent); err != nil {
				return err
			}
		default:
			return fmt.Errorf("unknown intent type: %s", intent.IntentType)
		}
	}

	return nil
}

func generateEMBBResources(rl *framework.ResourceList, intent *Intent) error {
	// Generate ConfigMap for eMBB configuration
	configMap := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("embb-config-%s", intent.IntentID),
			Namespace: "oran-intent",
			Labels: map[string]string{
				"intent-type": "eMBB",
				"intent-id":   intent.IntentID,
			},
		},
		Data: map[string]string{
			"bandwidth":     intent.ServiceProfile.Bandwidth,
			"target-sites":  strings.Join(intent.TargetSites, ","),
			"service-class": "enhanced-mobile-broadband",
			"qos-profile":   "high-throughput",
		},
	}

	if err := addResource(rl, configMap); err != nil {
		return err
	}

	// Generate Deployment for eMBB service
	deployment := &appsv1.Deployment{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "apps/v1",
			Kind:       "Deployment",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("embb-service-%s", intent.IntentID),
			Namespace: "oran-intent",
			Labels: map[string]string{
				"intent-type": "eMBB",
				"intent-id":   intent.IntentID,
			},
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": fmt.Sprintf("embb-%s", intent.IntentID),
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":         fmt.Sprintf("embb-%s", intent.IntentID),
						"intent-type": "eMBB",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "embb-service",
							Image: "oran/embb-service:latest",
							EnvFrom: []corev1.EnvFromSource{
								{
									ConfigMapRef: &corev1.ConfigMapEnvSource{
										LocalObjectReference: corev1.LocalObjectReference{
											Name: fmt.Sprintf("embb-config-%s", intent.IntentID),
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	return addResource(rl, deployment)
}

func generateURLLCResources(rl *framework.ResourceList, intent *Intent) error {
	// Generate ConfigMap for URLLC configuration
	configMap := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("urllc-config-%s", intent.IntentID),
			Namespace: "oran-intent",
			Labels: map[string]string{
				"intent-type": "URLLC",
				"intent-id":   intent.IntentID,
			},
		},
		Data: map[string]string{
			"latency":       intent.ServiceProfile.Latency,
			"reliability":   intent.ServiceProfile.Reliability,
			"target-sites":  strings.Join(intent.TargetSites, ","),
			"service-class": "ultra-reliable-low-latency",
			"qos-profile":   "mission-critical",
		},
	}

	return addResource(rl, configMap)
}

func generateMMTCResources(rl *framework.ResourceList, intent *Intent) error {
	// Generate ConfigMap for mMTC configuration
	configMap := &corev1.ConfigMap{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "ConfigMap",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("mmtc-config-%s", intent.IntentID),
			Namespace: "oran-intent",
			Labels: map[string]string{
				"intent-type": "mMTC",
				"intent-id":   intent.IntentID,
			},
		},
		Data: map[string]string{
			"device-density": intent.ServiceProfile.DeviceDensity,
			"target-sites":   strings.Join(intent.TargetSites, ","),
			"service-class":  "massive-iot",
			"qos-profile":    "best-effort",
		},
	}

	return addResource(rl, configMap)
}

func addResource(rl *framework.ResourceList, obj runtime.Object) error {
	data, err := json.Marshal(obj)
	if err != nil {
		return err
	}

	node, err := yaml.Parse(string(data))
	if err != nil {
		return err
	}

	rl.Items = append(rl.Items, *node)
	return nil
}

func int32Ptr(i int32) *int32 {
	return &i
}