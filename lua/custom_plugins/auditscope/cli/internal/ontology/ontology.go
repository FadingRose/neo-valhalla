package ontology

import "github.com/kobayakawayuu/auditscope/pkg/models"

var levels = map[string]int{
	models.NodeTypeNote:       0,
	models.NodeTypeEvidence:   0,
	models.NodeTypeInsight:    0,
	models.NodeTypeQuestion:   0,
	models.NodeTypeHypothesis: 0,
	models.NodeTypeFact:       0,
	models.NodeTypeAssumption: 0,
	models.NodeTypeInvariant:  0,
	models.NodeTypeFinding:    1,
	models.NodeTypeDecision:   2,
	models.NodeTypeRisk:       2,
}

func GetLevel(nodeType string) int {
	if level, ok := levels[nodeType]; ok {
		return level
	}
	return 0
}

func IsLinkAllowed(fromType, toType string) bool {
	fromLevel := GetLevel(fromType)
	toLevel := GetLevel(toType)
	if fromLevel == toLevel {
		return true
	}
	return fromLevel < toLevel
}

func DescribeRule(fromType, toType string) string {
	fromLevel := GetLevel(fromType)
	toLevel := GetLevel(toType)
	return "Rule: same level or upward only. From " + fromType + "(L" + string(rune('0'+fromLevel)) + ") to " + toType + "(L" + string(rune('0'+toLevel)) + ")."
}

func GetAllLevels() map[string]int {
	return levels
}
